module PanoramaSampler::PackagePanoramaSamplerBlockingLocks
  # PL/SQL-Package for blocking locks snapshot creation
  def panorama_sampler_blocking_locks_spec
    "
CREATE OR REPLACE Package panorama.Panorama_Sampler_Blocking_Locks AS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME

  PROCEDURE Create_Blocking_Locks_Snapshot(p_Instance_Number IN NUMBER, p_LongLocksSeconds IN NUMBER);

END Panorama_Sampler_Blocking_Locks;
    "
  end

  def panorama_sampler_blocking_locks_code
    "
  PROCEDURE Create_Blocking_Locks_Snapshot(p_Instance_Number IN NUMBER, p_LongLocksSeconds IN NUMBER) IS
    v_Waiting_For_PK_Column_Name  panorama.Panorama_Blocking_Locks.Waiting_For_PK_Column_Name%TYPE;
    v_Waiting_For_PK_Value        panorama.Panorama_Blocking_Locks.Waiting_For_PK_Value%TYPE;
    v_TableName                   VARCHAR2(30);
    v_First                       BOOLEAN;
    v_PKey_Cols                   VARCHAR2(300);
    v_Blocking_RowID              UROWID;
    v_Snapshot_Timestamp          DATE;
  BEGIN
    v_Snapshot_Timestamp := SYSDATE;    -- Einheitlicher Zeitpunkt des Schnappschuss ueber gesamte Verarbeitung
    FOR Rec IN (
                WITH RawLock AS (SELECT /*+ MATERIALIZE NO_MERGE */ * FROM gv$Lock)
                SELECT /*+ parallel(l,2) parallel(bo,2) */
                       l.Inst_ID,
                       s.SID,
                       s.Serial#,
                       s.SQL_ID,
                       s.SQL_Child_Number,
                       s.Prev_SQL_ID,
                       s.Prev_Child_Number,
                       s.Status,
                       s.Client_Info,
                       s.Module,
                       s.Action,
                       CASE
                       WHEN l.Type='TM' THEN /* Locked Object for TM */
                            (SELECT o.Owner||'.'||o.object_name FROM sys.dba_objects o WHERE l.id1=o.object_id)
                       WHEN l.Type='TX' THEN /* Used Rollback Segment for TX */
                            (SELECT DECODE(Count(*),1,'','Multi:')||MIN(SUBSTR('RBS:'||x.XIDUSN,1,18)) FROM GV$Transaction x WHERE x.Addr=s.TAddr)
                       END Object_Name,
                       s.UserName,
                       s.machine,
                       s.OSUser,
                       s.Process,
                       s.program,
                       l.Type                 Lock_Type,
                       bo.Owner               Blocking_Object_Owner,
                       bo.Object_Name         Blocking_Object_Name,
                       bo.Data_Object_ID,     -- fuer Ermittlung RowID
                       s.Row_Wait_File#,      -- fuer Ermittlung RowID
                       s.Row_Wait_Block#,     -- fuer Ermittlung RowID
                       s.Row_Wait_Row#,       -- fuer Ermittlung RowID
                       s.Seconds_In_Wait,
                       l.ID1,
                       l.ID2,
                       /* Request!=0 indicates waiting for resource determinded by ID1, ID2 */
                       l.Request Request,
                       l.lmode                Lock_Mode,
                       s.Blocking_Instance    Blocking_Instance_Number,
                       s.Blocking_Session     Blocking_SID,
                       bs.Serial#             Blocking_SerialNo,
                       bs.SQL_ID              Blocking_SQL_ID,
                       bs.SQL_Child_Number    Blocking_SQL_Child_Number,
                       bs.Prev_SQL_ID         Blocking_Prev_SQL_ID,
                       bs.Prev_Child_Number   Blocking_Prev_Child_Number,
                       bs.Status              Blocking_Status,
                       bs.Client_Info         Blocking_Client_Info,
                       bs.Module              Blocking_Module,
                       bs.Action              Blocking_Action,
                       bs.UserName            Blocking_User_Name,
                       bs.Machine             Blocking_Machine,
                       bs.OSUser              Blocking_OS_User,
                       bs.Process             Blocking_Process,
                       bs.Program             Blocking_Program
                 FROM RawLock l
                 JOIN gv$session s ON s.Inst_ID = l.Inst_ID AND s.SID = l.SID
                 LEFT OUTER JOIN gv$Session bs ON bs.Inst_ID = s.Blocking_Instance AND bs.SID = s.Blocking_Session
                 -- Object der blockenden Session
                 -- erst p2 abfragen, da bei Request=3 in row_wait_obj# das als vorletztes gelockte Objekt stehen kann
                 LEFT OUTER JOIN sys.DBA_Objects bo ON bo.Object_ID = CASE WHEN s.LockWait IS NOT NULL AND l.Request != 0 THEN /* Waiting for Lock */
                                                                           CASE WHEN s.P2Text = 'object #' THEN /* Wait kennt Objekt */ s.P2
                                                                           ELSE CASE WHEN s.Row_Wait_Obj# != -1 THEN /* Session kennt Objekt */   s.Row_Wait_Obj#
                                                                                ELSE NULL
                                                                                END
                                                                           END
                                                                      END
                 WHERE s.type = 'USER'
                 AND l.Type != 'PS'
                 AND bo.Object_Name != 'SEMAPHORE'  -- Diese Tabellen dienen der Prozessabgrenzung mittels blocking locks, muessen also nicht protokolliert werden
                 AND ((s.Seconds_In_Wait > p_LongLocksSeconds  AND l.Type NOT IN ('BR', 'MR') ) OR (s.LockWait IS NOT NULL AND l.Request != 0) )
    ) LOOP
      -- Ermitteln Primary Key-Values
      v_Waiting_For_PK_Column_Name := NULL;              -- Default
      v_Waiting_For_PK_Value      := NULL;              -- Default
      v_Blocking_RowID           := NULL;              -- Default
      v_TableName                := Rec.Blocking_Object_Name;         -- Default-Annahme, Objekt muss aber nicht Table sein
      v_Pkey_Cols                := '';

      -- Blocking RowID ermitteln
      IF Rec.Data_Object_ID IS NOT NULL THEN           -- Data-Object gefunden, dann Versuch, RowID zu ermitteln
        BEGIN -- Data_Object_ID verwenden statt Object_ID
          v_Blocking_RowID := DBMS_RowID.RowID_Create(1, Rec.Data_Object_ID, Rec.Row_Wait_File#, Rec.Row_Wait_Block#, Rec.Row_Wait_Row#);
        EXCEPTION
          WHEN SYS_INVALID_ROWID THEN
            NULL;
        END;
      END IF;

      -- Tablename ermitteln wenn Object_Name ein Index ist
      FOR iRec IN (SELECT Table_Name FROM All_Indexes WHERE Owner = Rec.Blocking_Object_Owner AND Index_Name = Rec.Blocking_Object_Name) LOOP
        v_TableName := iRec.Table_Name;               -- Index mit Name gefunden, Table uebernehmen
      END LOOP;

      -- Primary-Key-Spalten ermitteln wenn PKey existiert
      v_First := TRUE;
      FOR pRec IN (SELECT Column_Name
                   FROM   All_Ind_Columns
                   WHERE  Index_Owner   = Rec.Blocking_Object_Owner
                   AND    Index_Name    = (SELECT Index_Name
                                           FROM   All_Constraints
                                           WHERE  Owner      = Rec.Blocking_Object_Owner
                                           AND    Table_Name = v_TableName
                                           AND    Constraint_Type = 'P'
                                          )
                  ) LOOP
        IF v_First THEN
          v_First := FALSE;
        ELSE
          v_Pkey_Cols := v_PKey_Cols||'||'',''|| ';
        END IF;
        v_Pkey_Cols := v_PKey_Cols||pRec.Column_Name;
      END LOOP;

      -- Primary Key-Value ermitteln
      IF LENGTH(v_Pkey_Cols) > 0 AND v_Blocking_RowID IS NOT NULL THEN
        BEGIN
          v_Waiting_For_PK_Column_Name := REPLACE(REPLACE(v_Pkey_Cols, '|', ''), '''', '');
          EXECUTE IMMEDIATE 'SELECT '||v_Pkey_Cols||'
                             FROM '||Rec.Blocking_Object_Owner||'.'||v_TableName||'
                             WHERE RowID = :Row_ID'
          INTO v_Waiting_For_PK_Value USING v_Blocking_RowID;
        EXCEPTION
          WHEN NO_DATA_FOUND THEN
            v_Waiting_For_PK_Value := '[NO DATA FOUND]';
          WHEN SYS_INVALID_ROWID THEN
            v_Waiting_For_PK_Value := '[SYS_INVALID_ROWID]';
          WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Fehler bei Ermittlung Pkey aus RowID: '||Rec.Blocking_Object_Owner||'.'||v_TableName||'('||v_Pkey_Cols||
                                 ') für RowID='||v_Blocking_RowID);
            RAISE;
        END;
      END IF;

      BEGIN
      INSERT INTO panorama.Panorama_Blocking_Locks (
        Snapshot_Timestamp, Instance_Number, SID, SerialNo, SQL_ID, SQL_Child_Number, Prev_SQL_ID, Prev_Child_Number,
        Status, Client_Info, Module, Action, Object_Name, User_Name, Machine, OS_User, Process, Program,
        Lock_Type, Seconds_in_Wait, ID1, ID2, Request, Lock_mode,
        Blocking_Object_Owner, Blocking_Object_Name, Blocking_RowID, Blocking_Instance_Number, Blocking_SID, Blocking_SerialNo,
        Blocking_SQL_ID, Blocking_SQL_Child_Number, Blocking_Prev_SQL_ID, Blocking_Prev_Child_Number, Blocking_Status,
        Blocking_Client_Info, Blocking_Module, Blocking_Action, Blocking_User_name, Blocking_Machine, Blocking_OS_User,
        Blocking_Process, Blocking_Program, Waiting_For_PK_Column_Name, Waiting_For_PK_Value
      )
      VALUES (
        v_Snapshot_Timestamp, Rec.Inst_ID, Rec.SID, Rec.Serial#, Rec.SQL_ID, Rec.SQL_Child_Number, Rec.Prev_SQL_ID, Rec.Prev_Child_Number,
        Rec.Status, Rec.Client_Info, Rec.Module, Rec.Action, Rec.Object_Name, Rec.UserName, Rec.Machine, Rec.OSUser, Rec.Process, Rec.Program,
        Rec.Lock_Type, Rec.Seconds_In_Wait, Rec.ID1, Rec.ID2, Rec.Request, Rec.Lock_Mode,
        Rec.Blocking_Object_Owner, Rec.Blocking_Object_Name, v_Blocking_RowID, Rec.Blocking_Instance_Number, Rec.Blocking_SID, Rec.Blocking_SerialNo,
        Rec.Blocking_SQL_ID, Rec.Blocking_SQL_Child_Number, Rec.Blocking_Prev_SQL_ID, Rec.Blocking_Prev_Child_Number, Rec.Blocking_Status,
        Rec.Blocking_Client_Info, Rec.Blocking_Module, Rec.Blocking_Action, Rec.Blocking_User_name, Rec.Blocking_Machine, Rec.Blocking_OS_User,
        Rec.Blocking_Process, Rec.Blocking_Program, v_Waiting_For_PK_Column_Name, v_Waiting_For_PK_Value
      );
      EXCEPTION
        WHEN OTHERS THEN
          DBMS_OUTPUT.PUT_LINE('Fehler bei Insert in DBA_Hist_Blocking_Locks');
          DBMS_OUTPUT.PUT_LINE('SYSDATE='||v_Snapshot_Timestamp);
          DBMS_OUTPUT.PUT_LINE('Inst_ID='||Rec.Inst_ID);
          DBMS_OUTPUT.PUT_LINE('SID='||Rec.SID);
          DBMS_OUTPUT.PUT_LINE('Serial#='||Rec.Serial#);
          DBMS_OUTPUT.PUT_LINE('SQL_ID='||Rec.SQL_ID);
          DBMS_OUTPUT.PUT_LINE('SQL_Child_Number='||Rec.SQL_Child_Number);
          DBMS_OUTPUT.PUT_LINE('Prev_SQL_ID='||Rec.Prev_SQL_ID);
          DBMS_OUTPUT.PUT_LINE('Prev_Child_Number='||Rec.Prev_Child_Number);
          DBMS_OUTPUT.PUT_LINE('Status='||Rec.Status);
          DBMS_OUTPUT.PUT_LINE('Client_Info='||Rec.Client_Info);
          DBMS_OUTPUT.PUT_LINE('Module='||Rec.Module);
          DBMS_OUTPUT.PUT_LINE('Action='||Rec.Action);
          DBMS_OUTPUT.PUT_LINE('Object_Name='||Rec.Object_Name);
          DBMS_OUTPUT.PUT_LINE('User_Name='||Rec.UserName);
          DBMS_OUTPUT.PUT_LINE('Machine='||Rec.Machine);
          DBMS_OUTPUT.PUT_LINE('OSUser='||Rec.OSUser);
          DBMS_OUTPUT.PUT_LINE('Process='||Rec.Process);
          DBMS_OUTPUT.PUT_LINE('Program='||Rec.Program);
          DBMS_OUTPUT.PUT_LINE('Lock_Type='||Rec.Lock_Type);
          DBMS_OUTPUT.PUT_LINE('Seconds_In_Wait='||Rec.Seconds_In_Wait);
          DBMS_OUTPUT.PUT_LINE('ID1='||Rec.ID1);
          DBMS_OUTPUT.PUT_LINE('ID2='||Rec.ID2);
          DBMS_OUTPUT.PUT_LINE('Request='||Rec.Request);
          DBMS_OUTPUT.PUT_LINE('Lock_Mode='||Rec.Lock_Mode);
          DBMS_OUTPUT.PUT_LINE('Blocking_Object_Owner='||Rec.Blocking_Object_Owner);
          DBMS_OUTPUT.PUT_LINE('Blocking_Object_Name='||Rec.Blocking_Object_Name);
          DBMS_OUTPUT.PUT_LINE('Blocking_RowID='||v_Blocking_RowID);
          DBMS_OUTPUT.PUT_LINE('Blocking_Instance_Number='||Rec.Blocking_Instance_Number);
          DBMS_OUTPUT.PUT_LINE('Blocking_SID='||Rec.Blocking_SID);
          DBMS_OUTPUT.PUT_LINE('Blocking_SerialNo='||Rec.Blocking_SerialNo);
          DBMS_OUTPUT.PUT_LINE('Blocking_SQL_ID='||Rec.Blocking_SQL_ID);
          DBMS_OUTPUT.PUT_LINE('Blocking_SQL_Child_Number='||Rec.Blocking_SQL_Child_Number);
          DBMS_OUTPUT.PUT_LINE('Blocking_Prev_SQL_ID='||Rec.Blocking_Prev_SQL_ID);
          DBMS_OUTPUT.PUT_LINE('Blocking_Prev_Child_Number='||Rec.Blocking_Prev_Child_Number);
          DBMS_OUTPUT.PUT_LINE('Blocking_Status='||Rec.Blocking_Status);
          DBMS_OUTPUT.PUT_LINE('Blocking_Client_Info='||Rec.Blocking_Client_Info);
          DBMS_OUTPUT.PUT_LINE('Blocking_Module='||Rec.Blocking_Module);
          DBMS_OUTPUT.PUT_LINE('Blocking_Action='||Rec.Blocking_Action);
          DBMS_OUTPUT.PUT_LINE('Blocking_User_name='||Rec.Blocking_User_name);
          DBMS_OUTPUT.PUT_LINE('Blocking_Machine='||Rec.Blocking_Machine);
          DBMS_OUTPUT.PUT_LINE('Blocking_OS_User='||Rec.Blocking_OS_User);
          DBMS_OUTPUT.PUT_LINE('Blocking_Process='||Rec.Blocking_Process);
          DBMS_OUTPUT.PUT_LINE('Blocking_Program='||Rec.Blocking_Program);
          DBMS_OUTPUT.PUT_LINE('Waiting_For_PK_Column_Name='||v_Waiting_For_PK_Column_Name);
          DBMS_OUTPUT.PUT_LINE('Waiting_For_PK_Value='||v_Waiting_For_PK_Value);
          RAISE;
      END;
    END LOOP;
  END Create_Blocking_Locks_Snapshot;
    "
  end

  def panorama_sampler_blocking_locks_body
    "
-- Package for use by Panorama-Sampler
CREATE OR REPLACE PACKAGE BODY panorama.Panorama_Sampler_Blocking_Locks AS
  -- Panorama-Version: PANORAMA_VERSION
  -- Compiled at COMPILE_TIME_BY_PANORAMA_ENSURES_CHANGE_OF_LAST_DDL_TIME
#{panorama_sampler_blocking_locks_code}
END Panorama_Sampler_Blocking_Locks;
"
  end


end