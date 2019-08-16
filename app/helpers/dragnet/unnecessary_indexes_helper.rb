# encoding: utf-8
module Dragnet::UnnecessaryIndexesHelper

  private

  def unnecessary_indexes
    [
        {
            :name  => t(:dragnet_helper_7_name, :default=> 'Detection of indexes not used for access or ensurance of uniqueness'),
            :desc  => t(:dragnet_helper_7_desc, :default=>"Selection of non-unique indexes without usage in SQL statements.
Necessity of  existence of indexes may be put into question if these indexes are not used for uniqueness or access optimization.
However the index may be useful for coverage of foreign key constraints, even if there had been no usage of index in considered time period.
Ultimate knowledge about usage of index may be gained by tagging index with 'ALTER INDEX ... MONITORING USAGE' and monitoring usage via V$OBJECT_USAGE.
Additional info about usage of index can be gained by querying DBA_Hist_Seg_Stat or DBA_Hist_Active_Sess_History."),
            :sql=> "SELECT /* DB-Tools Ramm nicht genutzte Indizes */ * FROM (
                    SELECT (SELECT SUM(bytes)/(1024*1024) MBytes FROM DBA_SEGMENTS s WHERE s.SEGMENT_NAME = i.Index_Name AND s.Owner = i.Owner) MBytes,
                                i.Num_Rows, i.Owner, i.Index_Name, i.Index_Type, i.Tablespace_Name, i.Table_Owner, i.Table_Name, i.UniqueNess, i.Distinct_Keys,
                                (SELECT Column_Name FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name AND Column_Position=1) Column_1,
                                (SELECT Column_Name FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name AND Column_Position=2) Column_2,
                                (SELECT Count(*) FROM DBA_Ind_Columns c WHERE c.Index_Owner=i.Owner AND c.Index_Name=i.Index_Name) Anzahl_Columns,
                                (SELECT MIN(f.Constraint_Name||' Table='||rf.Table_Name)
                                 FROM   DBA_Constraints f
                                 JOIN   DBA_Cons_Columns fc ON fc.Owner = f.Owner AND fc.Constraint_Name = f.Constraint_Name AND fc.Position=1
                                 JOIN   DBA_Ind_Columns ic ON ic.Column_Name=fc.Column_Name AND ic.Column_Position=1
                                 JOIN   DBA_Constraints rf ON rf.Owner=f.r_Owner AND rf.Constraint_Name=f.r_Constraint_Name
                                 WHERE  f.Owner = i.Table_Owner
                                 AND    f.Table_Name = i.Table_Name
                                 AND    f.Constraint_Type = 'R'
                                 AND    ic.Index_Owner=i.Owner AND  ic.Index_Name=i.Index_Name
                                ) Ref_Constraint
                    FROM   (SELECT /*+ NO_MERGE */ i.*
                            FROM   DBA_Indexes i
                            LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ DISTINCT p.Object_Owner, p.Object_Name
                                             FROM   gV$SQL_Plan p
                                             JOIN   gv$SQL t ON t.Inst_ID=p.Inst_ID AND t.SQL_ID=p.SQL_ID
                                             WHERE  t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                            ) p ON p.Object_Owner=i.Owner AND p.Object_Name=i.Index_Name
                            LEFT OUTER JOIN (SELECT /*+ NO_MERGE PARALLEL(p,2) PARALLEL(s,2) PARALLEL(ss,2) PARALLEL(t,2) */ DISTINCT p.Object_Owner, p.Object_Name
                                             FROM   DBA_Hist_SQL_Plan p
                                             JOIN   DBA_Hist_SQLStat s
                                                    ON  s.DBID            = p.DBID
                                                    AND s.SQL_ID          = p.SQL_ID
                                                    AND s.Plan_Hash_Value = p.Plan_Hash_Value
                                             JOIN   DBA_Hist_SnapShot ss
                                                    ON  ss.DBID      = s.DBID
                                                    AND ss.Snap_ID = s.Snap_ID
                                                    AND ss.Instance_Number = s.Instance_Number
                                             JOIN   (SELECT /*+ NO_MERGE PARALLEL(t,2) */ t.DBID, t.SQL_ID
                                                     FROM   DBA_Hist_SQLText t
                                                     WHERE  t.SQL_Text NOT LIKE '%dbms_stats cursor_sharing_exact%' /* DBMS-Stats-Statement */
                                                    ) t
                                                    ON  t.DBID   = p.DBID
                                                    AND t.SQL_ID = p.SQL_ID
                                             WHERE  ss.Begin_Interval_Time > SYSDATE-?
                                            ) hp ON hp.Object_Owner=i.Owner AND hp.Object_Name=i.Index_Name
                            WHERE   p.OBJECT_OWNER IS NULL AND p.Object_Name IS NULL  -- keine Treffer im Outer Join
                            AND     hp.OBJECT_OWNER IS NULL AND hp.Object_Name IS NULL  -- keine Treffer im Outer Join
                            AND     i.Owner NOT IN ('SYS', 'OUTLN', 'SYSTEM', 'WMSYS', 'SYSMAN', 'XDB')
                            AND     i.UNiqueness != 'UNIQUE'
                           ) i
                    ) ORDER BY MBytes DESC NULLS LAST, Num_Rows",
            :parameter=>[{:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') }]
        },
        {
            :name  => t(:dragnet_helper_14_name, :default=> 'Detection of indexes with only one or little key values in index'),
            :desc  => t(:dragnet_helper_14_desc, :default=> 'Indexes with only one or little key values may be unnecessary.
                       Exception: Indexes with only one key value may be usefull for differentiation between NULL and NOT NULL.
                       Indexes with only one key value and no NULLs in indexed columns my be definitely removed.
                       If used for ensurance of foreign keys you can often relinquish on these index because resulting FullTableScan on referencing table
                       in case of delete on referenced table may be accepted.'),
            :sql=> "SELECT /* DB-Tools Ramm Sinnlose Indizes */
                            i.Owner \"Owner\", i.Table_Name, Index_Name, Index_Type, BLevel, Distinct_Keys,
                            ROUND(i.Num_Rows/DECODE(i.Distinct_Keys,0,1,i.Distinct_Keys)) \"Rows per Key\",
                            i.Num_Rows \"Rows Index\", t.Num_Rows \"Rows Table\", t.Num_Rows-i.Num_Rows \"Possible NULLs\", t.IOT_Type,
                            s.MBytes,
                            (SELECT CASE WHEN SUM(DECODE(Nullable, 'N', 1, 0)) = COUNT(*) THEN 'NOT NULL' ELSE 'NULLABLE' END
                             FROM DBA_Ind_Columns ic
                             JOIN DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                             WHERE  ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                            ) Nullable
                     FROM   DBA_Indexes i
                     JOIN   DBA_Tables t ON t.Owner=i.Table_Owner AND t.Table_Name=i.Table_Name
                     LEFT OUTER JOIN (SELECT  /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                      FROM   DBA_SEGMENTS s
                                      GROUP BY Owner, Segment_Name
                                     ) s ON s.SEGMENT_NAME = i.Index_Name AND s.Owner = i.Owner
                     WHERE   i.Num_Rows >= ?
                     AND     i.Distinct_Keys<=?
                     ORDER BY i.Num_Rows*t.Num_Rows DESC NULLS LAST
                      ",
            :parameter=>[{:name=>t(:dragnet_helper_14_param_1_name, :default=> 'Min. number of rows in index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_14_param_1_hint, :default=> 'Minimum number of rows in considered index') },
                         {:name=>t(:dragnet_helper_14_param_2_name, :default=> 'Max. number of key values in index'), :size=>8, :default=>10, :title=>t(:dragnet_helper_14_param_2_hint, :default=> 'Maximum number of distinct key values in considered index') }
            ]
        },
        {
            :name  => t(:dragnet_helper_8_name, :default=> 'Detection of indexes with multiple indexed columns'),
            :desc  => t(:dragnet_helper_8_desc, :default=> 'This selection looks for indexes where one index indexes a subset of the columns of the other index, both starting with the same columns.
The purpose of the index with the smaller column set can regularly be covered by the second index with the larger column set (including protection of foreign key constraints).
So the first index often can be dropped without loss of function.
The effect of less indexes to maintain and less objects in database cache with better cache hit rate for the remaining objects in cache is mostly higher rated than the possible overhead of using range scan on index with larger column set.

If the index with the smaller column set ensures uniqueness, than an unique constraint with this column set based on the second index with the larger column set can also cover this task.
'),
            :sql=> "
WITH Ind_Cols AS (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Listagg(Column_Name, ',') WITHIN GROUP (ORDER BY Column_Position) Columns
                  FROM   DBA_Ind_Columns
                  GROUP BY Index_Owner, Index_Name
                 ),
     Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Index_Name, Table_Owner, Table_Name, Num_Rows, Uniqueness
                 FROM   DBA_Indexes
                 WHERE  Tablespace_Name NOT IN ('SYSTEM', 'SYSAUX')
                )
SELECT x.*, ROUND(s.MBytes, 2) Size_MB_Index1
FROM   (
        SELECT i1.owner, i1.Table_Name,
               i1.Index_Name Index_1, ic1.Columns Columns_1, i1.Num_Rows Num_Rows_1, i1.Uniqueness Uniqueness_1,
               i2.Index_Name Index_2, ic2.Columns Columns_2, i2.Num_Rows Num_Rows_2, i2.Uniqueness Uniqueness_2
        FROM   Indexes i1
        JOIN   Indexes i2 ON i2.Table_Owner = i1.Table_Owner AND i2.Table_Name = i1.Table_Name
        JOIN   Ind_Cols ic1 ON ic1.Index_Owner = i1.Owner AND ic1.Index_Name = i1.Index_Name
        JOIN   Ind_Cols ic2 ON ic2.Index_Owner = i2.Owner AND ic2.Index_Name = i2.Index_Name
        WHERE  i1.Index_Name != i2.Index_Name
        AND    ic2.Columns LIKE ic1.Columns || ',%' /* Columns of i1 are already indexed by i2 */
        AND    i1.Num_Rows > ?
       ) x
LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, SUM(Bytes)/(1024*1024) MBytes
                 FROM DBA_Segments
                 GROUP BY Owner, Segment_Name
                ) s ON s.Owner = x.Owner AND s.Segment_Name = x.Index_1
ORDER BY s.MBytes DESC NULLS LAST
            ",
            :parameter=>[{:name=> t(:dragnet_helper_8_param_1_name, :default=>'Minmum number of rows for index'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_8_param_1_hint, :default=>'Minimum number of rows of index for consideration in result')}]
        },
        {
            :name  => t(:dragnet_helper_9_name, :default=> 'Detection of unused indexes by MONITORING USAGE'),
            :desc  => t(:dragnet_helper_9_desc, :default=>"DB monitors usage (access) on indexes if declared so before by 'ALTER INDEX ... MONITORING USAGE'.
Results of usage monitoring can be queried from v$Object_Usage but only for current schema.
Over all schemas usage can be monitored with following SQL.
Caution:
- Recursive index-lookup by foreign key validation does not count as usage in v$Object_Usage.
- So please be careful if index is only needed for foreign key protection (to prevent full scans on detail-table at deletes on master-table).
- GATHER_TABLE_STATS and GATHER_INDEX_STATS may also counts as usage even if no other select touches this index (no longer detected in DB-version >= 12).

Additional information about index usage can be requested from DBA_Hist_Seg_Stat and DBA_Hist_Active_Sess_History."),
            :sql=> "
                    WITH Constraints AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Constraint_Name, Constraint_Type, Table_Name, R_Owner, R_Constraint_Name FROM DBA_Constraints),
                         Ind_Columns AS        (SELECT /*+ NO_MERGE MATERIALIZE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_name, Column_Position FROM DBA_Ind_Columns),
                         Cons_Columns AS       (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Column_name, Position, Constraint_Name FROM DBA_Cons_Columns),
                         Tables AS             (SELECT /*+ NO_MERGE MATERIALIZE */  Owner, Table_Name, Num_Rows, Last_analyzed FROM DBA_Tables),
                         Tab_Modifications AS  (SELECT /*+ NO_MERGE MATERIALIZE */  Table_Owner, Table_Name, Inserts, Updates, Deletes FROM DBA_Tab_Modifications WHERE Partition_Name IS NULL /* Summe der Partitionen wird noch einmal als Einzel-Zeile ausgewiesen */)
                    SELECT /*+ USE_HASH(i ic cc c rc rt) */ u.Owner, u.Table_Name, u.Index_Name,
                           ic.Column_Name                                                             \"First Column name\",
                           u.\"Start monitoring\",
                           ROUND(NVL(u.\"End monitoring\", SYSDATE)-u.\"Start monitoring\", 1) \"Days without usage\",
                           i.Num_Rows \"Num. rows\", i.Distinct_Keys \"Distinct keys\",
                           CASE WHEN i.Distinct_Keys IS NULL OR  i.Distinct_Keys = 0 THEN NULL ELSE ROUND(i.Num_Rows/i.Distinct_Keys) END \"Avg. rows per key\",
                           i.Compression||CASE WHEN i.Compression = 'ENABLED' THEN ' ('||i.Prefix_Length||')' END Compression,
                           seg.MBytes,
                           i.Uniqueness||CASE WHEN i.Uniqueness != 'UNIQUE' AND uc.Constraint_Name IS NOT NULL THEN ' enforcing '||uc.Constraint_Name END Uniqueness,
                           cc.Constraint_Name                                                         \"Foreign key protection\",
                           CASE WHEN cc.r_Table_Name IS NOT NULL THEN LOWER(cc.r_Owner)||'. '||cc.r_Table_Name END  \"Referenced table\",
                           cc.r_Num_Rows                                                              \"Num rows of referenced table\",
                           cc.r_Last_analyzed                                                         \"Last analyze referenced table\",
                           cc.Inserts                                                                 \"Inserts on ref. since anal.\",
                           cc.Updates                                                                 \"Updates on ref. since anal.\",
                           cc.Deletes                                                                 \"Deletes on ref. since anal.\",
                           i.Tablespace_Name                                                          \"Tablespace\",
                           u.\"End monitoring\",
                           i.Index_Type,
                           (SELECT IOT_Type FROM DBA_Tables t WHERE t.Owner = u.Owner AND t.Table_Name = u.Table_Name) \"IOT Type\"
                    FROM   (
                            SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name, t.name Table_Name,
                                   decode(bitand(i.flags, 65536), 0, 'NO', 'YES') Monitoring,
                                   decode(bitand(ou.flags, 1), 0, 'NO', 'YES') Used,
                                   TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') \"Start monitoring\",
                                   TO_DATE(ou.End_Monitoring, 'MM/DD/YYYY HH24:MI:SS')   \"End monitoring\"
                            FROM   sys.object_usage ou
                            JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                            JOIN   sys.obj$ io ON io.obj# = ou.obj#
                            JOIN   sys.obj$ t  ON t.obj# = i.bo#
                            JOIN   DBA_Users u ON u.User_ID = io.owner#  --
                            CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                            WHERE  TO_DATE(ou.Start_Monitoring, 'MM/DD/YYYY HH24:MI:SS') < SYSDATE-?
                            AND    (schema.name IS NULL OR schema.Name = u.UserName)
                           )u
                    JOIN DBA_Indexes i                    ON i.Owner = u.Owner AND i.Index_Name = u.Index_Name AND i.Table_Name=u.Table_Name
                    LEFT OUTER JOIN Ind_Columns ic        ON ic.Index_Owner = u.Owner AND ic.Index_Name = u.Index_Name AND ic.Column_Position = 1
                    /* Indexes used for protection of FOREIGN KEY constraints */
                    LEFT OUTER JOIN (SELECT cc.Owner, cc.Table_Name, cc.Column_name, c.Constraint_Name, rc.Owner r_Owner, rt.Table_Name r_Table_Name, rt.Num_rows r_Num_rows, rt.Last_Analyzed r_Last_analyzed, m.Inserts, m.Updates, m.Deletes
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c     ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type = 'R'
                                     JOIN   Constraints rc    ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
                                     JOIN   Tables rt     ON rt.Owner = rc.Owner AND rt.Table_Name = rc.Table_Name
                                     LEFT OUTER JOIN Tab_Modifications m ON m.Table_Owner = rc.Owner AND m.Table_Name = rc.Table_Name
                                     WHERE  cc.Position = 1
                                    ) cc ON cc.Owner = ic.Table_Owner AND cc.Table_Name = ic.Table_Name AND cc.Column_Name = ic.Column_Name
                    /* Indexes used for enforcement of UNIQUE or PRIMARY KEY constraints */
                    LEFT OUTER JOIN (SELECT ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     FROM   Cons_Columns cc
                                     JOIN   Constraints c   ON c.Owner = cc.Owner AND c.Constraint_Name = cc.Constraint_Name AND c.Constraint_Type IN ('U', 'P')
                                     LEFT OUTER JOIN Ind_Columns ic ON ic.Table_Owner = cc.Owner AND ic.Table_Name = cc.Table_Name  AND ic.Column_Name = cc.Column_Name AND ic.Column_Position = cc.Position
                                     GROUP BY ic.Index_Owner, ic.Index_Name, c.Constraint_Name
                                     HAVING COUNT(DISTINCT cc.Column_Name) = COUNT(DISTINCT ic.Column_Name)
                                    ) uc ON uc.Index_Owner = u.Owner AND uc.Index_Name = u.Index_Name
                    JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes
                          FROM   DBA_Segments
                          GROUP BY Owner, Segment_Name
                          HAVING SUM(bytes)/(1024*1024) > ?
                         ) seg ON seg.Owner = u.Owner AND seg.Segment_Name = u.Index_Name
                    CROSS JOIN (SELECT ? value FROM DUAL) Max_DML
                    WHERE u.Used='NO' AND u.Monitoring='YES'
                    AND   (? = 'YES' OR i.Uniqueness != 'UNIQUE')
                    AND   (Max_DML.Value IS NULL OR NVL(cc.Inserts + cc.Updates + cc.Deletes, 0) < Max_DML.Value)
                    ORDER BY seg.MBytes DESC NULLS LAST
                   ",
          :parameter=>[{:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_9_param_3_hint, :default=>'List only indexes for this schema (optional)')},
                       {:name=>t(:dragnet_helper_9_param_1_name, :default=>'Number of days backwards without usage'),    :size=>8, :default=>7,   :title=>t(:dragnet_helper_9_param_1_hint, :default=>'Minumin age in days of Start-Monitoring timestamp of unused index')},
                       {:name=>t(:dragnet_helper_139_param_1_name, :default=>'Minimum size of index in MB'),    :size=>8, :default=>1,   :title=>t(:dragnet_helper_139_param_1_hint, :default=>'Minumin size of index in MB to be considered in selection')},
                       {:name=>t(:dragnet_helper_9_param_4_name, :default=>'Maximum DML-operations on referenced table'), :size=>8, :default=>'',   :title=>t(:dragnet_helper_9_param_4_hint, :default=>'Maximum number of DML-operations (Inserts + Updates + Deletes) on referenced table since last analyze (optional)')},
                       {:name=>t(:dragnet_helper_9_param_2_name, :default=>'Show unique indexes also (YES/NO)'), :size=>4, :default=>'NO',   :title=>t(:dragnet_helper_9_param_2_hint, :default=>'Unique indexes are needed for uniqueness even if they are not used')},
            ]
        },
        {
            :name  => t(:dragnet_helper_139_name, :default=> 'Detection of indexes without MONITORING USAGE'),
            :desc  => t(:dragnet_helper_139_desc, :default=>"It is recommended to let the DB track usage of indexes by ALTER INDEX ... MONITORING USAGE
so you may identify indexes that are never used for direct index access from SQL.
This usage info should be refreshed from time to time to recognize also indexes that aren't used anymore.
How to and scripts for activating MONITORING USAGE may be found here:

  %{url}

Index usage can be evaluated than via v$Object_Usage or with previous selection.
", url: "https://rammpeter.blogspot.com/2017/10/oracle-db-identify-unused-indexes.html"),
            :sql=> "
                    SELECT i.Owner, i.Table_Name, i.Index_Name, i.Index_Type, i.Num_Rows, i.Distinct_Keys, seg.MBytes, o.Created, o.Last_DDL_Time
                    FROM   DBA_Indexes i
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                                    ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                    LEFT OUTER JOIN (
                                      SELECT /*+ NO_MERGE */ u.UserName Owner, io.name Index_Name
                                      FROM   sys.object_usage ou
                                      JOIN   sys.ind$ i  ON i.obj# = ou.obj#
                                      JOIN   sys.obj$ io ON io.obj# = ou.obj#
                                      JOIN   DBA_Users u ON u.User_ID = io.owner#
                                    ) u ON u.Owner = i.Owner AND u.Index_Name = i.Index_Name
                    LEFT OUTER JOIN DBA_Objects o ON o.Owner = i.Owner AND o.Object_Name = i.Index_Name AND o.Object_Type = 'INDEX'
                    CROSS JOIN (SELECT ? Schema FROM DUAL) s
                    WHERE u.Owner IS NULL AND u.Index_Name IS NULL
                    AND   i.Owner NOT IN ('SYS', 'SYSTEM', 'XDB', 'ORDDATA', 'MDSYS', 'OLAPSYS')
                    AND   seg.MBytes > ?
                    AND   (s.Schema IS NULL OR i.Owner = UPPER(s.Schema))
                    ORDER BY seg.MBytes DESC NULLS LAST
            ",
            :parameter=>[{:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_139_param_2_hint, :default=>'List only indexes for this schema (optional)')},
                         {:name=>t(:dragnet_helper_139_param_1_name, :default=>'Minimum size of index in MB'),    :size=>8, :default=>1,   :title=>t(:dragnet_helper_139_param_1_hint, :default=>'Minumin size of index in MB to be considered in selection')},
            ]
        },
        {
            :name  => t(:dragnet_helper_10_name, :default=> 'Detection of indexes with unnecessary columns because of pure selectivity'),
            :desc  => t(:dragnet_helper_10_desc, :default=>"For multi-column indexes with high selectivity of single columns often additional columns in index don't  improve selectivity of that index.
Additional columns with low selectivity are useful only if:
- they essentially improve selectivity of whole index
- they allow index-only data access without accessing table itself
Without these reasons additional columns with low selectivity may be removed from index.
This selection already suppresses indexes used for elimination of 'table access by rowid'."),
            :sql=> "SELECT /* DB-Tools Ramm: low selectivity */ *
                        FROM
                               (
                                SELECT /*+ NO_MERGE USE_HASH(i ms io) */
                                       i.Owner, i.Table_Name, i.Index_Name, i.Num_Rows,
                                       seg.MBytes \"MBytes\",
                                       ms.Column_Name \"Max. selective column\", ms.Max_Num_Distinct,
                                       ROUND(ms.Max_Num_Distinct / i.Num_Rows, 2) \"Max. selectivity\",
                                       tc.Column_Name \"Min. selective column\", tc.Num_Distinct \"Min. num. distinct\"
                                FROM   DBA_Indexes i
                                JOIN   (SELECT /*+ NO_MERGE USE_HASH(ic tc ) */ /* Max. Selektivit‰t einer Spalte eines Index */
                                               ic.Index_Owner, ic.Index_Name, MAX(tc.Num_Distinct) Max_Num_Distinct,
                                               MAX(ic.Column_Name) KEEP (DENSE_RANK LAST ORDER BY tc.Num_Distinct) Column_Name
                                        FROM   (SELECT /*+ NO_MERGE */ Index_Owner, Index_Name, Table_Owner, Table_Name, Column_Name FROM DBA_Ind_Columns) ic
                                        JOIN   (SELECT /*+ NO_MERGE */ Owner, Table_Name, Column_Name, Num_Distinct FROM DBA_Tab_Columns
                                               ) tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                                        GROUP BY ic.Index_Owner, ic.Index_Name
                                       ) ms ON ms.Index_Owner = i.Owner AND ms.Index_Name = i.Index_Name
                                JOIN   DBA_Ind_Columns ic ON ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name
                                JOIN   DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                                LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ /* SQL mit Zugriff auf Index ohne Zugriff auf Table existieren */ i.Owner, i.Index_Name
                                                 FROM   DBA_Indexes i
                                                 JOIN   GV$SQL_Plan p1 ON p1.Object_Owner = i.Owner AND p1.Object_Name = i.Index_Name
                                                 LEFT OUTER JOIN   GV$SQL_Plan p2 ON p2.Inst_ID = p1.Inst_ID AND p2.SQL_ID = p1.SQL_ID AND p2.Plan_Hash_Value = p1.Plan_Hash_Value
                                                                                  AND p2.Object_Owner = i.Table_Owner AND p2.Object_Name = i.Table_Name
                                                 WHERE p2.Inst_ID IS NULL AND P2.SQL_ID IS NULL AND p2.Plan_Hash_Value IS NULL
                                                 AND   i.UniqueNess = 'NONUNIQUE'
                                                 GROUP BY i.Owner, i.Index_Name
                                                ) io ON io.Owner = i.Owner AND io.Index_Name = i.Index_Name
                                LEFT OUTER JOIN (SELECT Owner, Segment_Name, ROUND(SUM(bytes)/(1024*1024),1) MBytes FROM DBA_Segments GROUP BY Owner, Segment_Name
                                                ) seg ON seg.Owner = i.Owner AND seg.Segment_Name = i.Index_Name
                                WHERE  i.Num_Rows IS NOT NULL AND i.Num_Rows > 0
                                AND    ms.Max_Num_Distinct > i.Num_Rows/?   -- Ein Feld mit gen∏gend groﬂer Selektivit‰t existiert im Index
                                AND    tc.Column_Name != ms.Column_Name     -- Spalte mit hoechster Selektivit‰t ausblenden
                                AND    i.UniqueNess = 'NONUNIQUE'
                                AND    io.Owner IS NULL AND io.Index_Name IS NULL -- keine Zugriffe, bei denen alle Felder aus Index kommen und kein TableAccess nˆtig wird
                               ) o
                        WHERE  o.Owner NOT IN ('SYS', 'OLAPSYS', 'SYSMAN', 'WMSYS', 'CTXSYS')
                        AND    Num_Rows > ?
                        ORDER BY Max_Num_Distinct / Num_Rows DESC NULLS LAST",
            :parameter=>[{:name=>t(:dragnet_helper_10_param_1_name, :default=>'Largest selectivity of a column of index > 1/x to the number of rows'), :size=>8, :default=>4, :title=>t(:dragnet_helper_10_param_1_hint, :default=>'Number of DISTINCT-values of index column with largest selectivity is > 1/x to the number of rows on index')},
                         {:name=>t(:dragnet_helper_10_param_2_name, :default=>'Minimum number of rows of index'), :size=>8, :default=>100000, :title=>t(:dragnet_helper_10_param_2_hint, :default=>'Minimum number of rows of index for consideration in selection')}
            ]
        },
        {
            :name  => t(:dragnet_helper_6_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially unnecessary indexes)'),
            :desc  => t(:dragnet_helper_6_desc, :default=>"Protection of existing foreign key constraint by index on referencing column may be unnecessary if:
- there are no physical deletes on referenced table
- full table scan on referencing table is acceptable during delete on referenced table
- possible shared lock issues on referencing table due to not existing index are no problem
Especially for references from large tables to small master data tables often there's no use for the effort of indexing referencing column.
Due to the poor selectivity such indexes are mostly not useful for access optimization."),
            :sql=> "WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name , Constraint_Name, Constraint_Type, R_Owner, R_Constraint_Name, Index_Name
                     FROM   DBA_Constraints
                     WHERE  Constraint_Type IN ('R', 'P', 'U')
                     AND    Owner NOT IN ('CTXSYS', 'DBSNMP', 'SYS', 'SYSTEM', 'XDB')
                    )
                    SELECT /* DB-Tools Ramm Unnecessary index on Ref-Constraint*/
                           ri.Owner, ri.Table_Name, ri.Index_Name, ri.Rows_Origin \"No. of rows origin\", s.Size_MB \"Size of Index in MB\", p.Constraint_Name, ri.Column_Name,
                           ri.Position, pi.Table_Name Target_Table, pi.Index_Name Target_Index, pi.Num_Rows \"No. of rows target\", ri.No_of_Referencing_FK \"No. of referencing fk\"
                    FROM   (SELECT /*+ NO_MERGE */
                                   r.Owner, r.Table_Name, r.Constraint_Name, rc.Column_Name, rc.Position, ric.Index_Name,
                                   r.R_Owner, r.R_Constraint_Name, ri.Num_Rows Rows_Origin
                            FROM   Constraints r
                            JOIN   DBA_Cons_Columns rc  ON rc.Owner            = r.Owner            /* Columns of foreign key */
                                                       AND rc.Constraint_Name  = r.Constraint_Name
                            JOIN   DBA_Ind_Columns ric  ON ric.Table_Owner     = r.Owner            /* matching columns of an index */
                                                       AND ric.Table_Name      = r.Table_Name
                                                       AND ric.Column_Name     = rc.Column_Name
                                                       AND ric.Column_Position = rc.Position
                            JOIN   DBA_Indexes ri       ON ri.Owner            = ric.Index_Owner
                                                       AND ri.Index_Name       = ric.Index_Name
                            WHERE  r.Constraint_Type  = 'R'
                           ) ri                      -- Indizierte Foreign Key-Constraints
                    JOIN   Constraints p   ON p.Owner            = ri.R_Owner                   /* referenced PKey-Constraint */
                                          AND p.Constraint_Name  = ri.R_Constraint_Name
                    JOIN   DBA_Indexes     pi  ON pi.Owner           = p.Owner
                                              AND pi.Index_Name      = p.Index_Name
                    JOIN   (SELECT /*+ NO_MERGE */ r_Owner, r_Constraint_Name, COUNT(*) No_of_Referencing_FK /* Limit fk-target to max. x referencing tables */
                            FROM   Constraints
                            WHERE  Constraint_Type = 'R'
                            GROUP BY r_Owner, r_Constraint_Name
                           ) ri ON ri.r_owner = p.Owner AND ri.R_Constraint_Name=p.Constraint_Name
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Owner, Segment_Name, ROUND(SUM(Bytes)/(1024*1024)) Size_MB
                                     FROM   DBA_Segments
                                     WHERE  Segment_Type LIKE 'INDEX%'
                                     GROUP BY Owner, Segment_Name
                                    ) s ON s.Owner = ri.Owner AND s.Segment_Name = ri.Index_Name
                    WHERE  pi.Num_Rows < ?                                                          /* Limit to small referenced tables */
                    AND    ri.Rows_Origin > ?                                                       /* Limit to huge referencing tables */
                    ORDER BY Rows_Origin DESC NULLS LAST",
            :parameter=>[
                         {:name=> t(:dragnet_helper_6_param_1_name, :default=>'Max. number of rows in referenced table'), :size=>8, :default=>100, :title=> t(:dragnet_helper_6_param_1_hint, :default=>'Max. number of rows in referenced table')},
                         {:name=> t(:dragnet_helper_6_param_2_name, :default=>'Min. number of rows in referencing table'), :size=>8, :default=>100000, :title=> t(:dragnet_helper_6_param_2_hint, :default=>'Minimun number of rows in referencing table')},
            ]
        },
        {
            :name  => t(:dragnet_helper_131_name, :default=> 'Indexes on partitioned tables with same columns like partition keys'),
            :desc  => t(:dragnet_helper_131_desc, :default=>"If an index on partitioned table indexes the same columns like partition key and partitioning itself is selective enough by partition pruning
than this index can be removed"),
            :sql=> "SELECT x.Owner, x.Index_Name, x.Table_Owner, x.Table_Name, x.Uniqueness, x.Index_Partitioned, x.Num_Rows, x.Distinct_Keys, x.Partition_Columns, x.Table_Partitions, x.MBytes
                    FROM   (
                            SELECT i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Uniqueness, i.Partitioned Index_Partitioned, i.Num_Rows, i.Distinct_Keys,
                                   COUNT(DISTINCT pc.Column_Name) Partition_Columns, COUNT(ic.Column_Name) Matching_Index_Columns,
                                   (SELECT COUNT(*) FROM DBA_Ind_Columns ici WHERE ici.Index_Owner = i.Owner AND ici.Index_Name = i.Index_Name) Total_Index_Columns,
                                   (SELECT COUNT(*)
                                    FROM   DBA_Tab_Partitions tp
                                    WHERE  tp.Table_Owner = i.Table_Owner
                                    AND    tp.Table_Name  = i.Table_Name
                                   ) Table_Partitions,
                                   (SELECT  ROUND(SUM(bytes)/(1024*1024),1) MBytes
                                    FROM   DBA_SEGMENTS s
                                    WHERE  s.SEGMENT_NAME = i.Index_Name
                                    AND    s.Owner        = i.Owner
                                   ) MBytes
                            FROM   DBA_Indexes i
                            JOIN   DBA_Part_Key_Columns pc ON pc.Owner = i.Table_Owner AND pc.Name = i.Table_Name AND pc.Object_Type = 'TABLE'
                            LEFT OUTER JOIN DBA_Ind_Columns ic ON  ic.Index_Owner = i.Owner AND ic.Index_Name = i.Index_Name AND ic.Column_Name = pc.Column_Name AND ic.Column_Position = pc.Column_Position
                            WHERE  i.Owner NOT IN ('SYSTEM', 'SYS')
                            AND    i.Uniqueness != 'UNIQUE'
                            GROUP BY i.Owner, i.Index_Name, i.Table_Owner, i.Table_Name, i.Uniqueness, i.Partitioned,  i.Num_Rows, i.Distinct_Keys
                           ) x
                    WHERE Partition_Columns      = Matching_Index_Columns
                    AND   Matching_Index_Columns = Total_Index_Columns      -- keine weiteren Spalten des Index
                    ORDER BY x.Distinct_Keys / DECODE(Table_Partitions, 0, 1, Table_Partitions), x.Num_Rows DESC
                    ",
        },
        {
            :name  => t(:dragnet_helper_143_name, :default=> 'Removable indexes if column order of another multi-column index can be changed'),
            :desc  => t(:dragnet_helper_143_desc, :default=>"This selection looks for multi-column indexes with first column with weak selectivity and second column with strong selectivity and another single-column index existing with the same column like the second column of the multi-column index.
If column order of the multi-column index can be changed than the additional single-column index may become obsolete."),
            :sql=> "WITH Indexes AS (SELECT /*+ NO_MERGE MATERIALIZE */ Table_Owner, Table_Name, Owner, Index_Name, Uniqueness, Num_Rows
                                     FROM   DBA_Indexes
                                    ),
                         Ind_Columns AS (SELECT /*+ NO_MERGE MATERIALIZE */ ic.Index_Owner, ic.Index_Name, ic.Table_Owner, ic.Table_Name, ic.Column_Name, ic.Column_Position, tc.Num_Distinct, tc.Avg_Col_Len
                                         FROM   DBA_Ind_Columns ic
                                         JOIN   DBA_Tab_Columns tc ON tc.Owner = ic.Table_Owner AND tc.Table_Name = ic.Table_Name AND tc.Column_Name = ic.Column_Name
                                         WHERE  tc.Num_Distinct IS NOT NULL /* Check only analyzed tables/indexes*/
                                         AND    tc.Num_Distinct > 0         /* Suppress division by zero */
                                        )
                    SELECT /*+ ORDERED */ i.Table_Owner, i.Table_Name, i.Index_Name Index_To_Change, i.Uniqueness, i.Num_Rows,
                           ic1.Column_Name Column_1, ic1.Num_Distinct Num_Dictinct_Col_1, ROUND(i.num_rows/ic1.Num_Distinct, 1) Rows_per_Key_Col_1,
                           ic2.Column_Name Column_2, ic2.Num_Distinct Num_Dictinct_Col_2, ROUND(i.num_rows/ic2.Num_Distinct, 1) Rows_per_Key_Col_2,
                           ica.Index_Name Index_To_Remove
                    FROM   Indexes i
                    JOIN   Ind_Columns ic1 ON ic1.Index_Owner = i.Owner AND ic1.Index_Name = i.Index_Name AND ic1.Column_Position = 1   /* First column of multi-column-index */
                    JOIN   Ind_Columns ic2 ON ic2.Index_Owner = i.Owner AND ic2.Index_Name = i.Index_Name AND ic2.Column_Position = 2   /* Second column of multi-column-index */
                    JOIN   Ind_Columns ica ON ica.Table_Owner = i.Table_Owner AND ica.Table_Name = i.Table_Name AND ica.Column_Name = ic2.Column_Name AND ica.Column_Position = 1 /* single-column index with same column as second column of multi-column index*/
                    WHERE  i.num_rows/ic1.Num_Distinct > ?
                    AND    i.num_rows/ic2.Num_Distinct < ?
                    ORDER BY i.Num_Rows * ica.Avg_Col_Len DESC  /* Order by saving after removal of ica-index */
            ",
            :parameter=>[
                {:name=> t(:dragnet_helper_143_param_1_name, :default=>'Min. rows per key for first column of index'), :size=>10, :default=>100000, :title=> t(:dragnet_helper_143_param_1_hint, :default=>'Minimun number of rows per key for first column of multi-column index')},
                {:name=> t(:dragnet_helper_143_param_2_name, :default=>'Max. rows per key for second column of index'), :size=>10, :default=>1000,  :title=> t(:dragnet_helper_143_param_2_hint, :default=>'Maximun number of rows per key for second column of multi-column index')},
            ]
        },

    ]
  end # unnecessary_indexes


end