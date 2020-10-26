# encoding: utf-8
module Dragnet::ForeignKeyConstraintHelper

  private

  def dragnet_foreign_key_constraint
    [
        {
            :name  => t(:dragnet_helper_5_name, :default=> 'Coverage of foreign-key relations by indexes (detection of potentially missing indexes)'),
            :desc  => t(:dragnet_helper_5_desc, :default=> 'Protection of colums with foreign key references by index can be necessary for:
- Ensure delete performance of referenced table (suppress FullTable-Scan)
- Supress lock propagation (shared lock on index instead of table)'),
            :sql=> "WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_name, Constraint_Type, r_Owner, r_Constraint_Name
                                         FROM   DBA_Constraints
                                         WHERE  Owner NOT IN (#{system_schema_subselect})
                                        )
                    SELECT /* DB-Tools Ramm  Index fehlt fuer Foreign Key*/
                           Ref.Owner, Ref.Table_Name \"Tablename\",
                           reft.Num_Rows Rows_Org,
                           refcol.Column_Name, refcol.Position,
                           Ref.R_Owner Target_Owner, target.Table_Name Target_Table, targett.Num_rows Rows_Target, Ref.R_Constraint_Name, targett.Last_Analyzed Last_Analyzed_Target,
                           target_mod.Deletes \"Target Deletes since analyze\"
                    FROM   Constraints Ref
                    JOIN   DBA_Cons_Columns refcol  ON refcol.Owner = Ref.Owner AND refcol.Constraint_Name = ref.Constraint_Name
                    JOIN   Constraints target       ON target.Owner = ref.R_Owner AND target.Constraint_Name = ref.R_Constraint_Name
                    JOIN   DBA_Tables reft          ON reft.Owner = ref.Owner AND reft.Table_Name = ref.Table_Name
                    JOIN   DBA_Tables targett       ON targett.Owner = target.Owner AND targett.Table_Name = target.Table_Name
                    LEFT OUTER JOIN (SELECT /*+ NO_MERGE */ Table_Owner, Table_Name, SUM(Deletes) Deletes
                                     FROM   DBA_Tab_Modifications
                                     GROUP BY Table_Owner, Table_Name
                                    ) target_mod ON target_mod.Table_Owner = target.Owner AND target_mod.Table_Name = target.Table_Name
                    WHERE  Ref.Constraint_Type='R'
                    AND    NOT EXISTS (SELECT 1 FROM DBA_Ind_Columns i
                                       WHERE  i.Table_Owner     = ref.Owner
                                       AND    i.Table_Name      = ref.Table_Name
                                       AND    i.Column_Name     = refcol.Column_Name
                                       AND    i.Column_Position = refcol.Position
                                       )
                    AND targett.Num_rows > ?
                    ORDER BY targett.Num_rows DESC NULLS LAST, ref.Table_Name, refcol.Position",
            :parameter=>[{:name=>t(:dragnet_helper_5_param_1_name, :default=> 'Min. no. of rows of referenced table'), :size=>8, :default=>1000, :title=>t(:dragnet_helper_5_param_1_hint, :default=> 'Minimum number of rows of referenced table') },]
        },
        {
            :name  => t(:dragnet_helper_5_name, :default=> 'Non validated foreign key constraints'),
            :desc  => t(:dragnet_helper_5_desc, :default=> 'Non validated foreign key constraints prevent the usage of some optimizer features like JOIN ELIMINATION.
For full availability of all optimizer features foreign key constraints should be regularly validated.

Missing validation can be effectively made up by temporary setting parallel degree for table:
ALTER TABLE <tab> PARALLEL x;
ALTER TABLE <tab> MODIFY CONSTRAINT <constraint> VALIDATE;
ALTER TABLE <tab> NOPARALLEL;
  '),
            :sql=> "\
WITH Constraints AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Constraint_Name, Constraint_Type, r_Owner, r_Constraint_Name, Validated, Last_Change FROM DBA_Constraints),
     Tables AS (SELECT /*+ NO_MERGE MATERIALIZE */ Owner, Table_Name, Num_Rows FROM DBA_Tables)
SELECT c.Owner, c.Table_Name, t.Num_Rows, c.Constraint_Name, c.r_Owner, rt.Table_Name R_Table_Name, rt.Num_Rows r_Num_Rows, c.r_Constraint_Name, c.Last_Change
FROM   Constraints c
JOIN   Tables t       ON  t.Owner = c.Owner   AND t.Table_Name = c.Table_Name
JOIN   Constraints rc ON rc.Owner = c.R_Owner AND rc.Constraint_Name = c.R_Constraint_Name
JOIN   Tables rt      ON rt.Owner = rc.Owner  AND rt.Table_Name = rc.Table_Name
WHERE  c.Constraint_Type = 'R'
AND    c.Validated != 'VALIDATED'
AND    c.Owner NOT IN ('SYSTEM')
ORDER BY t.Num_Rows DESC",
        },

    ]
  end

end