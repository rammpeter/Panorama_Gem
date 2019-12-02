# encoding: utf-8

module AdditionHelper

  # Suppress partition types from beeing named
  def compact_object_type_sql_case(object_type_name)
    "CASE
       WHEN #{object_type_name} = 'INDEX PARTITION'    THEN 'INDEX'
       WHEN #{object_type_name} = 'INDEX SUBPARTITION' THEN 'INDEX'
       WHEN #{object_type_name} = 'LOB PARTITION'      THEN 'LOBSEGMENT'
       WHEN #{object_type_name} = 'LOB SUBPARTITION'   THEN 'LOBSEGMENT'
       WHEN #{object_type_name} = 'NESTED TABLE'       THEN 'TABLE'
       WHEN #{object_type_name} = 'TABLE PARTITION'    THEN 'TABLE'
       WHEN #{object_type_name} = 'TABLE SUBPARTITION' THEN 'TABLE'
     ELSE #{object_type_name} END
    "
  end

end

