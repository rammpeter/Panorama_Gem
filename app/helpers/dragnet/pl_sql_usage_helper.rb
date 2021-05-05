# encoding: utf-8
module Dragnet::PlSqlUsageHelper

  private

  def pl_sql_usage
    [
        {
            :name  => t(:dragnet_helper_58_name, :default=>'Usage of NVL with function call as alternative parameter'),
            :desc  => t(:dragnet_helper_58_desc, :default=>'Function NVL calculates expression in parameter 2 always, whether first parameter of NVL is NULL or not.
    For extensive calculations in expression for parameter 2 of NVL you should use COALESCE instead. This calculates expression for alternative only if decision parameter is really NULL.'),
            :sql=>  "
SELECT SQL_ID, Inst_ID, Parsing_Schema_Name, ROUND(Elapsed_Secs) Elapsed_Secs, Executions,
       NVL_Level \"NVL-Occurrence in SQL\", Char_Level Open_Bracket_Position, SUBSTR(NVL_Substr, 1, Min_Ende_Pos) NVL_Parameter
FROM   (
        SELECT x.*,
               MIN(CASE WHEN Opened-Closed=1 AND Char_=',' THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Komma_Pos,
               MIN(CASE WHEN Char_Level> 3 /* Laenge von NVL */ AND Opened-Closed=0 /* Alle Klammern wieder geschlossen */ THEN Char_Level ELSE NULL END) OVER (PARTITION BY SQL_ID, NVL_Level) Min_Ende_Pos
        FROM   (
                SELECT /*+ USE_MERGE(t pump100000) */ SQL_ID, Inst_ID, Parsing_Schema_Name, Elapsed_Secs, Executions, NVL_Level, Char_Level, SUBSTR(NVL_Substr, Char_Level, 1) Char_, NVL_Substr,
                       CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN Char_Level ELSE NULL END Klammer_Open,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = '(' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Opened,
                       SUM(CASE WHEN TO_CHAR(SUBSTR(NVL_Substr, Char_Level, 1)) = ')' THEN 1 ELSE 0 END) OVER (PARTITION BY t.SQL_ID, NVL_Level  ORDER BY Char_Level ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) Closed
                FROM   (
                        SELECT /*+ NO_MERGE USE_MERGE(a pump1000) */ NVL_Level,
                               -- INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level) NVL_Position,
                               TO_CHAR(SUBSTR(a.First_NVL_Substr, INSTR(a.First_NVL_Substr, 'NVL', 1, NVL_Level)+3, 3800)) NVL_Substr, /* SQL-String nach dem xten NVL bis zum Ende, mit max. 4000 Zeichen (incl. multibyte) als Char fuehren */
                               a.SQL_ID, a.Inst_ID, a.Parsing_Schema_Name, a.Elapsed_Secs, a.Executions
                        FROM   (
                                SELECT /*+ NO_MERGE */ a.SQL_ID, a.Inst_ID, a.Parsing_Schema_Name, a.Elapsed_Secs, a.Executions,
                                                       REPLACE(UPPER(SUBSTR(ai.SQL_FullText, INSTR(UPPER(ai.SQL_FullText), 'NVL'))), 'NVL2', '') First_NVL_Substr /* NVL+ nachfolgende Sequenz aber ohne NVL2 */
                                FROM   (
                                        SELECT SQL_ID, Inst_ID, Parsing_Schema_Name,
                                               SUM(Elapsed_Time)/1000000 Elapsed_Secs,
                                               SUM(Executions)           Executions
                                        FROM   gv$SQLArea
                                        WHERE  UPPER(SQL_FullText) LIKE '%NVL%'
                                        AND    Parsing_Schema_Name NOT IN (#{system_schema_subselect})
                                        GROUP BY SQL_ID, Inst_ID, Parsing_Schema_Name
                                       ) a
                                JOIN   gv$SQLArea ai ON ai.SQL_ID = a.SQL_ID AND ai.Inst_ID = a.Inst_ID AND ai.Parsing_Schema_Name = a.Parsing_Schema_Name
                                WHERE  a.Elapsed_Secs > ?
                               ) a
                        JOIN  (SELECT /*+ MATERIALIZE */ Level NVL_Level FROM DUAL CONNECT BY Level < 1000) Pump1000 ON INSTR(a.First_NVL_Substr, 'NVL', 1, Pump1000.NVL_Level) != 0  /* Ein Record je Vorkommen eines NVL im SQL, limitiert mit Level */
                       ) t
                JOIN  (SELECT /*+ MATERIALIZE */ Level Char_Level FROM DUAL CONNECT BY Level < 100000) Pump100000 ON SUBSTR(NVL_Substr, pump100000.Char_Level, 1) IN ('(', ')', ',') AND pump100000.Char_Level <= LENGTH(t.NVL_Substr) /* Ein Record je Zeichen des verbleibenden SQL-Strings, limitiert mit Level */
               ) x
       ) y
WHERE  Klammer_Open BETWEEN Komma_Pos AND Min_Ende_Pos
ORDER BY Elapsed_Secs DESC, SQL_ID, NVL_Level, CHAR_Level
           ",
            :parameter=>[
                {:name=> t(:dragnet_helper_58_param1_name, :default=>'Minimum runtime of SQL in seconds'), :size=>8, :default=> 1000, :title=> t(:dragnet_helper_58_param1_desc, :default=>'Minimum runtime of SQL in seconds for consideration in selection')},
            ]
        },
        {
            :name  => t(:dragnet_helper_129_name, :default=>'Identification of probably unused PL/SQL-objects'),
            :desc  => t(:dragnet_helper_129_desc, :default=>"PL/SQL-code may assumed to be unused and dispensable if there are no dependencies from other PL/SQL-code.
This must not be true because you need entry points to PL/SQL-processing that doesn't have dependencies from other PL/SQL-objects but are essential.
Therefor additional selection is useful, e.g. by filter based on name convention.
"),
            :sql=> "SELECT o.Owner, o.Object_Name, o.Object_Type, o.Created, o.Last_DDL_Time, o.Status
                    FROM   DBA_Objects o
                    CROSS JOIN (SELECT UPPER(?) Name FROM DUAL) schema
                    CROSS JOIN (SELECT UPPER(?) Filter FROM DUAL) name_filter_incl
                    CROSS JOIN (SELECT UPPER(?) Filter FROM DUAL) name_filter_excl
                    WHERE  o.Object_Type IN ('PROCEDURE', 'PACKAGE', 'TYPE', 'FUNCTION', 'SYNONYM')
                    AND    o.Owner NOT IN (#{system_schema_subselect})
                    AND    (schema.name IS NULL OR schema.Name = o.Owner)
                    AND    (name_filter_incl.Filter IS NULL OR o.Object_name LIKE '%'||name_filter_incl.Filter||'%')
                    AND    (name_filter_excl.Filter IS NULL OR o.Object_name NOT LIKE '%'||name_filter_excl.Filter||'%')
                    AND NOT EXISTS (SELECT 1
                                    FROM   DBA_Dependencies d
                                    WHERE  d.Referenced_Owner = o.Owner
                                    AND    d.Referenced_Name = o.Object_Name
                                    AND    d.Referenced_Type = o.Object_Type
                                    AND    (d.Type != 'SYNONYM' OR EXISTS (SELECT 1 FROM DBA_Dependencies di WHERE  di.Referenced_Owner = d.Owner AND di.Referenced_Name = d.Name AND di.Referenced_Type = d.Type) ) -- Synonyme ohne weitere Abhängigkeiten nicht werten
                                    AND    (   d.Type != 'PACKAGE BODY'
                                            OR d.Name != d.Referenced_Name                          /* Referenz von anderslautendem Body zählt als Abhängigkeit */
                                            OR EXISTS (SELECT 1 FROM DBA_Dependencies di WHERE  di.Referenced_Owner = d.Owner AND di.Referenced_Name = d.Name AND di.Referenced_Type = d.Type) /* Weitere Abhängigkeiten des Bodys eines Package zählen als Abhängigkeiten */
                                           )
                                   )
                    AND    o.Created < SYSDATE - ?
                    AND    o.Last_DDL_Time < SYSDATE - ?
           ",
            :parameter=>[
                {:name=>'Schema-Name (optional)',    :size=>20, :default=>'',   :title=>t(:dragnet_helper_129_param_1_hint, :default=>'Check only PL/SQL-objects for this schema (optional)')},
                {:name=>t(:dragnet_helper_129_param2_name, :default=>'Limit result to object names with this wildcard (optional)'),  :size=>30, :default=>'',   :title=>t(:dragnet_helper_129_param_2_hint, :default=>'Check only PL/SQL objects with names matching this wildcard-filter(optional)')},
                {:name=>t(:dragnet_helper_129_param3_name, :default=>'Exclude object_names with this wildcard from result (optional)'),  :size=>30, :default=>'',   :title=>t(:dragnet_helper_129_param_3_hint, :default=>'Exclude PL/SQL objects with names matching this wildcard-filter from check (optional)')},
                {:name=>t(:dragnet_helper_129_param4_name, :default=>'Minimum age of objects in days'), :size=>8, :default=> 100, :title=> t(:dragnet_helper_128_param4_desc, :default=>'Minimum number of days since creation of object')},
                {:name=>t(:dragnet_helper_129_param5_name, :default=>'Minimum days since last DDL'), :size=>8, :default=> 10, :title=> t(:dragnet_helper_128_param5_desc, :default=>'Minimum number of days since last DDL-operation on object')},
            ]
        },
        {
            :name  => t(:dragnet_helper_152_name, :default=>'Candidates for PRAGMA UDF in user-defined PL/SQL functions'),
            :desc  => t(:dragnet_helper_152_desc, :default=>"User-defined PL/SQL in SQL-statements may perform better without context switching with PRAGMA UDF.
This selection shows PL/SQL functions without PL/SQL code depending from.
In addition SQLs from SGA are shown which uses this function name in their SQL syntax.
"),
            :sql=> "\
WITH Procs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ p.Owner, p.Object_Name
                FROM   DBA_Procedures p
                WHERE  p.Object_Type = 'FUNCTION'
                AND    p.Owner NOT IN (#{system_schema_subselect})
                AND    (p.Owner, p.Object_Name, p.Object_Type) NOT IN (SELECT /*+ NO_MERGE */ DISTINCT d.Referenced_Owner, d.Referenced_Name, d.Referenced_Type /* all objects with PL/SQL dependency */
                                                                       FROM   DBA_Dependencies d
                                                                       JOIN   DBA_Procedures pl ON pl.Owner       = d.Owner /* Filters dependencies to PL/SQL only */
                                                                                               AND pl.Object_Name = d.Name
                                                                                               AND pl.Object_Type = d.Type
                                                                      )
                AND    (p.Owner, p.Object_Name, p.Object_Type) NOT IN (SELECT /*+ NO_MERGE */ Owner, Name, Type FROM DBA_Source WHERE UPPER(Text) LIKE '%PRAGMA%UDF%')
               ),
     SQLs as (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, SQL_ID, UPPER(SQL_Text) SQL_Text FROM GV$SQLTEXT_WITH_NEWLINES)
SELECT p.Owner, p.Object_Name, p.Inst_ID,
       ROUND(SUM(a.Elapsed_Time)/1000000) \"Elapsed time (secs) in SQL\",
       SUM(a.Executions)                  \"No. of executions in SQL\",
       COUNT(DISTINCT p.SQL_ID)           \"No. of different SQLs\",
       MAX(a.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY a.Elapsed_Time NULLS FIRST) \"SQL_ID with max. elapsed time\"
FROM   (SELECT p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
        FROM   Procs p
        LEFT OUTER JOIN   SQLs s ON s.SQL_Text LIKE '%'||p.Object_Name||'%'
        GROUP BY p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
       ) p
LEFT OUTER JOIN   gv$SQLArea a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID
GROUP BY p.Owner, p.Object_Name, p.Inst_ID
ORDER BY 4 DESC NULLS LAST
           ",
        },
        {
            :name  => t(:dragnet_helper_153_name, :default=>'Candidates for DETERMINISTIC in user-defined PL/SQL functions'),
            :desc  => t(:dragnet_helper_153_desc, :default=>"User-defined PL/SQL functions may be cached in session for subsequent calls with same parameters if they are declared as deterministic.
For functions without dependencies there is a high likelihood that they are deterministic.
This selection shows PL/SQL functions not declared as DETERMINISTIC and without any dependency other than sys.STANDARD.
In addition SQLs from SGA are shown which uses this function name in their SQL syntax.
"),
            :sql=> "\
WITH Procs AS  (SELECT /*+ NO_MERGE MATERIALIZE */ p.Owner, p.Object_Name
                FROM   DBA_Procedures p
                WHERE  Object_Type = 'FUNCTION'
                AND    Owner NOT IN (#{system_schema_subselect})
                AND    Deterministic = 'NO'
                AND    (Owner, Object_Name, Object_Type) NOT IN (SELECT /*+ NO_MERGE */ DISTINCT d.Owner, d.Name, d.Type
                                                                 FROM   DBA_Dependencies d
                                                                 WHERE  (Referenced_Owner != 'SYS' OR Referenced_Name != 'STANDARD')
                                                                )
               ),
     SQLs as (SELECT /*+ NO_MERGE MATERIALIZE */ Inst_ID, SQL_ID, UPPER(SQL_Text) SQL_Text FROM GV$SQLTEXT_WITH_NEWLINES)
SELECT p.Owner, p.Object_Name, p.Inst_ID,
       ROUND(SUM(a.Elapsed_Time)/1000000) \"Elapsed time (secs) in SQL\",
       SUM(a.Executions)                  \"No. of executions in SQL\",
       COUNT(DISTINCT p.SQL_ID)           \"No. of different SQLs\",
       MAX(a.SQL_ID) KEEP (DENSE_RANK LAST ORDER BY a.Elapsed_Time NULLS FIRST) \"SQL_ID with max. elapsed time\"
FROM   (SELECT p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
        FROM   Procs p
        LEFT OUTER JOIN   SQLs s ON s.SQL_Text LIKE '%'||p.Object_Name||'%'
        GROUP BY p.Owner, p.Object_Name, s.Inst_ID, s.SQL_ID
       ) p
LEFT OUTER JOIN   gv$SQLArea a ON a.Inst_ID = p.Inst_ID AND a.SQL_ID = p.SQL_ID
GROUP BY p.Owner, p.Object_Name, p.Inst_ID
ORDER BY 4 DESC NULLS LAST
           ",
        },
    ]
  end

end