# encoding: utf-8
module Dragnet::ViewIssuesHelper

  private

  def view_issues
    [
        {
            :name  => t(:dragnet_helper_138_name, :default => 'Views with ORDER BY in View-SQL'),
            :desc  => t(:dragnet_helper_138_desc, :default =>'Sorting of SQL result within views often is unnecessary because it is not known in view how the calling SQL processes the result.
Sorting should be placed in calling SQL instead of view if necessary.
Selection is PL/SQL-Code so you have to execute it outside Panorama.
'),
            :sql=> "SET SERVEROUTPUT ON;

DECLARE
  Res CLOB;
BEGIN
  DBMS_OUTPUT.ENABLE(10000000);
  DBMS_OUTPUT.PUT_LINE('Check Views for ORDER BY');
  FOR REC IN (SELECT Owner, View_Name FROM DBA_Views WHERE  Owner NOT IN ('SYS', 'SYSTEM', 'DBSNMP', 'WMSYS', 'CTXSYS', 'XDB', 'PUBLIC', 'OUTLN')) LOOP
    BEGIN
      Res := DBMS_METADATA.GET_DDL(object_type => 'VIEW', name => Rec.view_name, schema => Rec.owner);
      IF DBMS_LOB.Instr(UPPER(Res), 'ORDER BY') > 0 THEN
        DBMS_OUTPUT.PUT_LINE('View-Text contains ORDER BY: owner='||Rec.Owner||', View='||Rec.View_Name);
      END IF;
    EXCEPTION
      WHEN OTHERS THEN RAISE_APPLICATION_ERROR(-20999, 'Error '||SQLERRM||' getting DDL for owner='||Rec.Owner||', View='||Rec.View_Name);
    END;
  END LOOP;
END;
/",
            :parameter=>[]
        },

    ]
  end # view_issues

end