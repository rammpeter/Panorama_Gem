# encoding: utf-8
module Dragnet::InstanceSetupTuning

  private

  def instance_setup_tuning
    [
        {
            name:   'Inconsistent dependency timestamps between dependcy and parent object',
            desc:   'Timestamp of last specification change of a parent object (DBA_Objects.Timestamp) and timestamp of stored dependency should be identical.
If they differ this may be a reason for ORA-4068, ORA-4065, ORA-06508.
Solution: recompile affected objects
',
            sql:     "SELECT dep.p_Obj# Parent_Obj#, LOWER(po.Owner)||'.'||po.Object_Name Parent_Object, po.Object_Type Parent_Type, po.Status Parent_Status, po.Created Parent_Created, po.Last_DDL_Time Parent_Lst_DDL,
                             TO_DATE(po.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') Parent_Spec_TS, dep.p_Timestamp Dependency_Parent_TS,
                             dep.d_Obj# Dependent_Obj#, LOWER(d.Owner)||'.'||d.Object_Name Dependent_Object, d.Object_Type Dependent_Type, d.Status Dependent_Status
                      FROM   sys.dependency$ dep
                      LEFT OUTER JOIN sys.Obj$ o ON o.Obj# = dep.p_Obj#
                      LEFT OUTER JOIN DBA_Objects po ON po.Object_ID = dep.p_Obj#
                      LEFT OUTER JOIN DBA_Objects d ON d.Object_ID = dep.d_Obj#
                      WHERE TO_DATE(po.Timestamp, 'YYYY-MM-DD:HH24:MI:SS') != dep.p_Timestamp
                     ",
        },

    ]
  end # instance_setup_tuning


end


