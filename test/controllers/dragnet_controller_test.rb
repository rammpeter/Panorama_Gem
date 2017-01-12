# encoding: utf-8
require 'test_helper'
require 'json'

class DragnetControllerTest < ActionController::TestCase
  include DragnetHelper

  setup do
    #@routes = Engine.routes         # Suppress routing error if only routes for dummy application are active
    set_session_test_db_context{}
  end

  # Alle Menu-Einträge testen für die der Controller eine Action definiert hat
  test "test_controllers_menu_entries_with_actions" do
    call_controllers_menu_entries_with_actions
  end

  test "get_selection_list"  do
    get :get_selection_list, :params => {:format=>:json }
    assert_response :success
  end

  test "refresh_selected_data"  do
    get :refresh_selected_data, :params => {:format=>:js, :entry_id=>"_0_0_3" }
    assert_response :success
  end

  # Test all subitems of node
  # Error: Java::JavaLang::ClassCastException: org.jruby.RubyObject cannot be cast to org.jruby.RubyModule
  # if method is declared inside test
  def execute_tree(node)
    node.each do |entry|
      if entry['children']
        execute_tree(entry['children'])        # Test subnode's entries
      else
        # _1_1_4 excluded because ORA600 on Oracle12.1
        if !['_0_7', '_1_1_4', '_3_4', '_3_5', '_7_1'].include?(entry['id'])            # Exclude selections from test which are not executable
          full_entry = extract_entry_by_entry_id(entry['id'])                 # Get SQL from id

          params = {:format=>:html, :dragnet_hidden_entry_id=>entry['id'], :update_area=>:hugo}

          if full_entry[:parameter]
            full_entry[:parameter].each do |p|                                # Iterate over optional parameter of selection
              params[p[:name]] = p[:default]
            end
          end
          post  :exec_dragnet_sql, :params => params                          # call execution of SQL
          assert_response(:success, "Error testing dragnet SQL #{entry['id']} #{full_entry[:name]}")

          params[:commit_show] = 'hugo'
          post  :exec_dragnet_sql, :params => params                          # Call show SQL text
          assert_response :success
        end
      end
    end
  end

  test "exec_dragnet_sql"  do
    # get available selections
    get :get_selection_list, :params => {:format=>:json }
    dragnet_sqls = JSON.parse(@response.body)
    execute_tree(dragnet_sqls)                                                     # Test each dragnet SQL with default parameters
  end

  # Find unique name by random to ensure selection does not already exists in client_info.store
  test "personal_selection" do
    post :add_personal_selection, :params => {:format=>:html, :update_area=>:hugo, :selection => "
{
  name: \"Name of selection in list#{Random.rand(1000000)}\",
  desc: \"Explanation of selection in right dialog\",
  sql:  \"SELECT * FROM DBA_Tables WHERE Owner = ? AND Table_Name = ?\",
  parameter: [
    {
      name:     \"Name of parameter for \\\"owner\\\" in dialog\",
      title:    \"Description of parameter \\\"owner\\\" for mouseover hint\",
      size:     \"Size of input field for parameter \\\"owner\\\" in characters\",
      default:  \"SYS\",
    },
    {
      name:     \"Name of parameter for \\\"table_name\\\" in dialog\",
      title:    \"Description of parameter \\\"table_name\\\" for mouseover hint\",
      size:     \"Size of input field for parameter \\\"table_name\\\" in characters\",
      default:  \"AUD$\",
    },
  ]
}
    " }
    assert_response :success

    # :dragnet_hidden_entry_id=>"_8_0" depends from number of submenus in list
    post :exec_dragnet_sql, :params => {:format=>:html, :commit_drop=>"Drop personal SQL", :dragnet_hidden_entry_id=>"_8_0", :update_area=>:hugo }
    assert_response :success

  end

end

