# encoding: utf-8
require 'test_helper'

class DbaSchemaControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context

    initialize_min_max_snap_id_and_times

    lob_table = sql_select_first_row "SELECT Owner, Table_Name, Segment_Name FROM DBA_Lobs WHERE Segment_Created = 'YES' AND RowNum < 2"
    if lob_table
      @lob_owner        = lob_table.owner
      @lob_table_name   = lob_table.table_name
      @lob_segment_name = lob_table.segment_name
    end

    lob_part_table = sql_select_first_row "SELECT Table_Owner, Table_Name, Lob_Name, LOB_Partition_Name FROM DBA_Lob_Partitions WHERE Segment_Created = 'YES' AND RowNum < 2"
    if lob_part_table
      @lob_part_owner           = lob_part_table.table_owner
      @lob_part_table_name      = lob_part_table.table_name
      @lob_part_lob_name        = lob_part_table.lob_name
      @lob_part_partition_name  = lob_part_table.lob_partition_name
    end

    subpart_table = sql_select_first_row "SELECT Table_Owner, Table_Name, Partition_Name FROM DBA_Tab_SubPartitions WHERE Segment_Created = 'YES' AND RowNum < 2"
    if subpart_table
      @subpart_table_owner            = subpart_table.table_owner
      @subpart_table_table_name       = subpart_table.table_name
      @subpart_table_partition_name   = subpart_table.partition_name
    else
      puts "DbaSchemaControllerTest.setup: There are no table subpartitions in database"
      @subpart_table_owner            = nil
      @subpart_table_table_name       = nil
      @subpart_table_partition_name   = nil
    end

    subpart_index = sql_select_first_row "SELECT Index_Owner, Index_Name, Partition_Name FROM DBA_Ind_SubPartitions WHERE Segment_Created = 'YES' AND RowNum < 2"
    if subpart_index
      @subpart_index_owner            = subpart_index.index_owner
      @subpart_index_index_name       = subpart_index.index_name
      @subpart_index_partition_name   = subpart_index.partition_name
    else
      Rails.logger.info "DbaSchemaControllerTest.setup: There are no index subpartitions in database"
      @subpart_index_owner            = nil
      @subpart_index_index_name       = nil
      @subpart_index_partition_name   = nil
    end

  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "show_object_size with xhr: true"       do get  :show_object_size, :params => {:format=>:html, :update_area=>:hugo };   assert_response :success; end

  test "list_objects with xhr: true"  do
    post :list_objects, :params => {:format=>:html, :tablespace=>{:name=>"USERS"}, :schema=>{:name=>"SCOTT"}, :update_area=>:hugo };
    assert_response :success;

    post :list_objects, :params => {:format=>:html, sql_id: 'abcd', :update_area=>:hugo };
    assert_response :success;

    post :list_objects, :params => {:format=>:html, sql_id: 'abcd', child_number: 1, :update_area=>:hugo };
    assert_response :success;

    post :list_objects, :params => {:format=>:html, sql_id: 'abcd', child_address: 'ABCD16', :update_area=>:hugo };
    assert_response :success;
  end

  test "list_object_description with xhr: true" do
    [
        {owner: 'SYS',      segment_name: 'AUD$'},                              # Table
        {owner: 'SYS',      segment_name: 'AUD$%'},                             # Table (Wildcard with one hit)
        {owner: 'SYS',      segment_name: 'A%'},                                # (Wildcard with multiple hit)
        {owner: 'SYS',      segment_name: 'TAB$'},                              # Table
        {owner: 'SYS',      segment_name: 'COL$'},                              # Table
        {owner: nil,        segment_name: 'ALL_TABLES'},                        # View
        {owner: 'SYS',      segment_name: 'WRH$_ACTIVE_SESSION_HISTORY'},       # partitioned Table
        {owner: 'PUBLIC',   segment_name: 'V$ARCHIVE'},                         # Synonym
        {owner: 'SYS',      segment_name: 'DBMS_LOCK'},                         # Package oder Body
    ]
        .concat(get_db_version >= '12.1' ? [{owner: 'XDB',      segment_name: 'XDB$ANY'}] :  [])    # XML-Table instead of relational table
        .each do |object|
      get :list_object_description, :params => {format: :html, owner: object[:owner], segment_name: object[:segment_name], :update_area=>:hugo }
      assert_response :success
    end

    [nil, 1].each do |show_line_numbers|
      get :list_object_description, :params => {:format=>:html, :owner=>"SYS", :segment_name=>"DBMS_LOCK", :object_type=>'PACKAGE', show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success

      get :list_object_description, :params => {:format=>:html, :owner=>"SYS", :segment_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY', show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success
    end

    post :list_indexes, :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    post :list_current_index_stats, :params => {:format=>:html, :table_owner=>"SYS", :table_name=>"DIR$", :index_owner=>'SYS', :index_name=>'I_DIR1', :leaf_blocks=>1, :update_area=>:hugo }
    assert_response :success

    post :list_primary_key, :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post :list_check_constraints, :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post :list_references_from, :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_INST_DD", :update_area=>:hugo }
    assert_response :success

    post :list_references_to, :params => {:format=>:html, :owner=>"SYS", :table_name=>"HS$_PARALLEL_SAMPLE_DATA", :update_area=>:hugo }
    assert_response :success

    post :list_triggers, :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    [nil, 1].each do |show_line_numbers|
      post :list_trigger_body, :params => {:format=>:html, :owner=>"SYS", :trigger_name=>"LOGMNRGGC_TRIGGER", show_line_numbers: show_line_numbers, :update_area=>:hugo }
      assert_response :success
    end

    post :list_lobs, :params => {:format=>:html, :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    if @lob_part_owner                                                          # if lob partitions exists in this database
      get :list_lob_partitions, :params => {:format=>:html, :owner=>@lob_part_owner, :table_name=>@lob_part_table_name, :lob_name=>@lob_part_lob_name, :update_area=>:hugo }
      assert_response :success
    end

    get :list_table_partitions, :params => {:format=>:html, :owner=>"SYS", :table_name=>"WRH$_SQLSTAT", :update_area=>:hugo }
    assert_response :success

    if @subpart_table_owner
      get :list_table_subpartitions, :params => {:format=>:html, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name, :update_area=>:hugo }
      assert_response :success

      get :list_table_subpartitions, :params => {:format=>:html, :owner=>@subpart_table_owner, :table_name=>@subpart_table_table_name, :partition_name => @subpart_table_partition_name, :update_area=>:hugo }
      assert_response :success
    end

    get :list_index_partitions, :params => {:format=>:html, :owner=>"SYS", :index_name=>"WRH$_SQLSTAT_PK", :update_area=>:hugo }
    assert_response :success

    if @subpart_index_owner
      get :list_index_subpartitions, :params => {:format=>:html, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name, :update_area=>:hugo }
      assert_response :success

      get :list_index_subpartitions, :params => {:format=>:html, :owner=>@subpart_index_owner, :index_name=>@subpart_index_index_name, :partition_name => @subpart_table_partition_name, :update_area=>:hugo }
      assert_response :success
    end

    post :list_dbms_metadata_get_ddl, :params => {:format=>:html, :object_type=>'TABLE', :owner=>"SYS", :table_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

    post :list_dependencies, :params => {:format=>:html, :owner=>"SYS", :object_name=>"AUD$", :object_type=>'TABLE', :update_area=>:hugo }
    assert_response :success
    post :list_dependencies, :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBA_AUDIT_TRAIL", :object_type=>'VIEW', :update_area=>:hugo }
    assert_response :success
    post :list_dependencies, :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE', :update_area=>:hugo }
    assert_response :success
    post :list_dependencies, :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post :list_dependencies_from_me_tree, :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post :list_dependencies_im_from_tree, :params => {:format=>:html, :owner=>"SYS", :object_name=>"DBMS_LOCK", :object_type=>'PACKAGE BODY', :update_area=>:hugo }
    assert_response :success

    post :list_grants, :params => {:format=>:html, :owner=>"SYS", :object_name=>"AUD$", :update_area=>:hugo }
    assert_response :success

  end

  test "list_audit_trail with xhr: true" do
    get :list_audit_trail, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get :list_audit_trail, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get :list_audit_trail, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :sessionid=>12345, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get :list_audit_trail, :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"none", :update_area=>:hugo }
    assert_response :success

    get :list_audit_trail, :params => {:format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :os_user=>"Hugo", :db_user=>"Hugo",
        :machine=>"Hugo", :object_name=>"Hugo", :action_name=>"Hugo", :grouping=>"MI", :top_x=>"5", :update_area=>:hugo }
    assert_response :success

    get :list_audit_trail, :params => {:format=>:html,  :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end, :grouping=>"MI", :update_area=>:hugo }
    assert_response :success

  end

  test "list_object_nach_file_und_block with xhr: true" do
    get :list_object_nach_file_und_block, :params => {:format=>:html, :fileno=>1, :blockno=>1, :update_area=>:hugo }
    assert_response :success
  end

  test "list_space_usage with xhr: true" do
    Rails.logger.info "Table-Name for next test is #{@lob_owner}.#{@lob_table_name}"
    get :list_space_usage, params: {format: :html, owner: @lob_owner, segment_name: @lob_segment_name , update_area: :hugo }
    assert_response :success

    if @lob_part_owner
      Rails.logger.info "Table-Name for next test is #{@lob_part_owner}.#{@lob_part_table_name}"
      # all partitions
      get :list_space_usage, params: {format: :html, owner: @lob_part_owner, segment_name: @lob_part_lob_name , update_area: :hugo }
      assert_response :success
      # one partition
      get :list_space_usage, params: {format: :html, owner: @lob_part_owner, segment_name: @lob_part_lob_name, partition_name: @lob_part_partition_name , update_area: :hugo }
      assert_response :success
    end

    if @subpart_table_owner
      Rails.logger.info "Table-Name for next test is #{@subpart_table_owner}.#{@subpart_table_table_name}"
      # all partitions
      get :list_space_usage, params: {format: :html, owner: @subpart_table_owner, segment_name: @subpart_table_table_name , update_area: :hugo }
      assert_response :success
      # one partition
      get :list_space_usage, params: {format: :html, owner: @subpart_table_owner, segment_name: @subpart_table_table_name, partition_name: @subpart_table_partition_name , update_area: :hugo }
      assert_response :success
    end

    if @subpart_index_owner
      Rails.logger.info "Index-Name for next test is #{@subpart_index_owner}.#{@subpart_index_index_name}"
      # all partitions
      get :list_space_usage, params: {format: :html, owner: @subpart_index_owner, segment_name: @subpart_index_index_name , update_area: :hugo }
      assert_response :success
      # one partition
      get :list_space_usage, params: {format: :html, owner: @subpart_index_owner, segment_name: @subpart_index_index_name, partition_name: @subpart_index_partition_name , update_area: :hugo }
      assert_response :success
    end
  end

end
