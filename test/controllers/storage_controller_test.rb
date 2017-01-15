# encoding: utf-8
require 'test_helper'

class StorageControllerTest < ActionController::TestCase

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
    time_selection_end  = Time.new
    time_selection_start  = time_selection_end-10000
    @time_selection_end = time_selection_end.strftime("%d.%m.%Y %H:%M")
    @time_selection_start = time_selection_start.strftime("%d.%m.%Y %H:%M")
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

    get :list_mview_query_text, :params => { :format=>:html, :owner=>"Hugo", :name=>"Hugo", :update_area=>:hugo  }
    assert_response :success;

    get :list_real_num_rows, :params => { :format=>:html, :owner=>"sys", :name=>"obj$", :update_area=>:hugo  } # sys.user$ requires extra rights compared to SELECT ANY DICTIONARY in 12c
    assert_response :success;

    get  :tablespace_usage, :params => { :format=>:html, :update_area=>:hugo  }
    assert_response :success
  end

end
