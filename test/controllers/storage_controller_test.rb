# encoding: utf-8
require 'test_helper'

class StorageControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
    @tablespace_name = sql_select_one "SELECT MIN(Tablespace_Name) FROM DBA_Tablespaces"
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions with xhr: true" do
    call_controllers_menu_entries_with_actions
  end

  test "storage_controller with xhr: true" do

    get  :datafile_usage, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success

    post :list_materialized_view_action, :params => { :format=>:html, :registered_mviews => "Hugo", :update_area=>:hugo  }
    assert_response :success;

    post :list_materialized_view_action, :params => { :format=>:html, :all_mviews => "Hugo", :update_area=>:hugo  }
    assert_response :success;

    post :list_materialized_view_action, :params => { :format=>:html, :mview_logs => "Hugo", :update_area=>:hugo  }
    assert_response :success;

    get :list_registered_materialized_views, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success;

    get :list_registered_materialized_views, :params => { :format=>:html, :snapshot_id=>1, :update_area=>:hugo  }
    assert_response :success;

    get :list_all_materialized_views, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success;

    get :list_all_materialized_views, :params => { :format=>:html, :owner=>"Hugo", :name=>"Hugo", :update_area=>:hugo  }
    assert_response :success;

    get :list_materialized_view_logs, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success;

    get :list_materialized_view_logs, :params => { :format=>:html, :log_owner=>"Hugo", :log_name=>"Hugo", :update_area=>:hugo  }
    assert_response :success;

    get :list_snapshot_logs,  :params => { :format=>:html, :snapshot_id=>1, :update_area=>:hugo  }
    assert_response :success;

    get :list_snapshot_logs,  :params => { :format=>:html,  :log_owner=>"Hugo", :log_name=>"Hugo", :update_area=>:hugo  }
    assert_response :success;

    get :list_registered_mview_query_text, :params => { :format=>:html, :mview_id=>1, :update_area=>:hugo  }
    assert_response :success;

    get :list_real_num_rows, :params => { :format=>:html, :owner=>"sys", :name=>"obj$", :update_area=>:hugo  } # sys.user$ requires extra rights compared to SELECT ANY DICTIONARY in 12c
    assert_response :success;

    get  :tablespace_usage, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success
  end

  test "exadata with xhr: true" do
    post :list_exadata_cell_server, :params => { :format=>:html}
    assert_response :success

    post :list_exadata_cell_server, :params => { :format=>:html, :cellname=>'Hugo'}
    assert_response :success

    post :list_exadata_cell_physical_disk, :params => { :format=>:html}
    assert_response :success

    post :list_exadata_cell_physical_disk, :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk'}
    assert_response :success

    post :list_exadata_cell_cell_disk, :params => { :format=>:html}
    assert_response :success

    post :list_exadata_cell_cell_disk, :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk', :physical_disk_id=>'Hugo'}
    assert_response :success

    post :list_exadata_cell_grid_disk, :params => { :format=>:html}
    assert_response :success

    post :list_exadata_cell_grid_disk, :params => { :format=>:html, :cellname=>'Hugo', :disktype=>'HardDisk', :physical_disk_id=>'Hugo', :cell_disk_name=>'Hugo'}
    assert_response :success
  end

  test "temp with xhr: true" do
    post :list_temp_usage_sysmetric_historic, :params => { :format=>:html, :time_selection_start=>@time_selection_start, :time_selection_end=>@time_selection_end}
    assert_response :success
  end

  test "extents with xhr: true" do
    post :list_free_extents, :params => { :format=>:html, :tablespace => @tablespace_name}
    assert_response :success

    post :list_object_extents, :params => { :format=>:html, :owner => 'sys', :segment_name => 'obj$'}
    assert_response :success
  end

  test "list_sysaux_occupants with xhr: true" do
    post :list_sysaux_occupants, :params => { :format=>:html}
    assert_response :success
  end
end
