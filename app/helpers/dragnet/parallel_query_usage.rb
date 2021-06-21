# encoding: utf-8
module Dragnet::ParallelQueryUsage

  private

  def parallel_query_usage
    [
      {
        :name  => t(:dragnet_helper_159_name, :default=>'Current usage of parallel query by PQ coordinator sessions'),
        :desc  => t(:dragnet_helper_159_desc, :default=>"This selection lists all sessions currently accessing PQ servers"),
        :sql =>  "\
SELECT p.QCInst_ID Instance, p.QCSID SID, p.QCSerial# \"Serial number\", p.PQ_Sessions \"PQ sessions\", p.Degree, p.Req_Degree \"Requested degree\",
       s.UserName, s.SQL_ID, s.SQL_Exec_ID, s.SQL_Exec_Start, s.OSUser, s.Machine, s.Program, s.Module, s.Action, s.Logon_Time
FROM   (
        SELECT QCInst_ID, QCSID, QCSerial#, COUNT(*) PQ_Sessions, MAX(Degree) Degree, MAX(Req_Degree) Req_Degree
        FROM   gv$PX_Session
        WHERE  SID != QCSID     /* exclude the coordinator itself */
        GROUP BY QCInst_ID, QCSID, QCSerial#
       ) p
LEFT OUTER JOIN gv$Session s ON s.Inst_ID = p.QCInst_ID  AND s.SID=p.QCSID AND s.Serial# =  p.QCSerial#
ORDER BY p.PQ_Sessions DESC"
      },
      {
        :name  => t(:dragnet_helper_160_name, :default=>'Active PQ sessions from Active Session History (ASH)'),
        :desc  => t(:dragnet_helper_160_desc, :default=>"This selection shows the number of active sessions from PQ servers"),
        :sql =>  "\
SELECT x.*, u.UserName
FROM   (SELECT Start_Sample, MIN(Min_Sessions) Min_active_PQ_Sessions, MAX(Max_Sessions) Max_active_PQ_Sessions,
               MAX(Max_SQL_ID)  KEEP (DENSE_RANK LAST ORDER BY Max_Sessions) Max_SQL_ID,
               MAX(Max_User_ID) KEEP (DENSE_RANK LAST ORDER BY Max_Sessions) Max_User_ID
        FROM   (
                SELECT Sample_Time, TRUNC(Sample_Time, ?) Start_Sample, MIN(Sessions) Min_Sessions, MAX(Sessions) Max_Sessions,
                       MAX(SQL_ID)  KEEP (DENSE_RANK LAST ORDER BY Sessions) Max_SQL_ID,
                       MAX(User_ID) KEEP (DENSE_RANK LAST ORDER BY Sessions) Max_User_ID
                FROM   (
                        SELECT Instance_Number, Sample_Time, SQL_ID, User_ID, COUNT(*) Sessions
                        FROM   (
                                SELECT /*+ NO_MERGE ORDERED */
                                       Instance_Number, Sample_Time, SQL_ID, User_ID
                                FROM   DBA_Hist_Active_Sess_History s
                                LEFT OUTER JOIN   (SELECT /*+ NO_MERGE */ Inst_ID, MIN(Sample_Time) Min_Sample_Time FROM gv$Active_Session_History GROUP BY Inst_ID) v ON v.Inst_ID = s.Instance_Number
                                WHERE  (v.Min_Sample_Time IS NULL OR s.Sample_Time < v.Min_Sample_Time)  -- Nur Daten lesen, die nicht in gv$Active_Session_History vorkommen
                                AND    DBID = (SELECT DBID FROM v$Database) /* Suppress multiple occurrence of records in PDB environment */
                                AND    QC_SESSION_ID IS NOT NULL
                                UNION ALL
                                SELECT Inst_ID Instance_Number, Sample_Time, SQL_ID, User_ID
                                FROM gv$Active_Session_History
                                WHERE  QC_SESSION_ID IS NOT NULL
                               )
                        GROUP BY Instance_Number, Sample_Time, SQL_ID, User_ID
                       ) h
                CROSS JOIN (SELECT NULL Instance_Number FROM DUAL) d
                WHERE  Sample_Time > SYSDATE - ?
                AND    (d.Instance_Number IS NULL OR h.Instance_Number = d.Instance_Number)
                GROUP BY Sample_Time
               )
        GROUP BY Start_Sample
       ) x
LEFT OUTER JOIN All_Users u ON u.User_ID = x.Max_User_ID
ORDER BY 1",
        :parameter=>[
          {:name=> 'Format picture for grouping by TRUNC-function', :size=>8, :default=> 'HH24', :title=> 'Format-picture of TRUNC function (DD=day, HH24=hour, MI=minute etc.)'},
          {:name=>t(:dragnet_helper_param_history_backward_name, :default=>'Consideration of history backward in days'), :size=>8, :default=>8, :title=>t(:dragnet_helper_param_history_backward_hint, :default=>'Number of days in history backward from now for consideration') },
        ]
      },
    ]
  end # parallel_query_usage


end


