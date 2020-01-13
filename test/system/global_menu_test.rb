require "test_helper"

class GlobalMenuTest < ApplicationSystemTestCase

  setup do
    set_session_test_db_context                                                 # Ensure existence of Panorama-Sampler tables at least
  end

  test "visiting the index" do
     visit root_path
  #
  #   assert_selector "h1", text: "HugoSys"
  end



  # Build tree with all menu links
  def get_menu_entries(menu_ul, click_tree_ids)
    # Iterate menues
    menu_ul.all(:xpath, './li', visible: false).each do |menu_li|
      menu_link = menu_li.find(:xpath, './a', visible: false)
      next_menu_uls = menu_li.all(:xpath, './ul', visible: false)
      if next_menu_uls.count == 0                                               # Menu is item
        Rails.logger.info "#{Time.now}: Menu entry #{menu_link[:id]}"
        @menu_links << {id: menu_link[:id], click_tree_ids: click_tree_ids}
      else                                                                      # Menu is node
        Rails.logger.info "#{Time.now}: Submenu #{menu_link[:id]}"
        get_menu_entries(next_menu_uls[0], click_tree_ids.clone << menu_link[:id])              # process items of node
      end
    end
  end


  test "All menu entries" do
    login_until_menu
    top_ul = page.find(:css, '#main_menu > .sf-menu')

    @menu_links = []                                                            # Hierarchic array
    get_menu_entries(top_ul, [])

    @menu_links.each do |menu_link|
      menu_link[:click_tree_ids].each do |menu_node_id|
        begin
          menu_node = wait_for_css_visibility('#main_menu #'+menu_node_id, true)
          raise "Menu node '#main_menu ##{menu_node_id}' not visible" if menu_node.nil?
          menu_node.hover                                                       # Let submenu appear
        rescue Exception=>e
          raise "Exception #{e.class}: #{e.message}\nProcessing hover on menues of #{menu_link[:id]} at menu node #{menu_node_id}"
        end
      end

      begin
        # Capybara.ignore_hidden_elements = false
        sleep 0.1                                                               # try to prevent Selenium::WebDriver::Error::NoSuchDriverError: invalid session id
        link_to_click = wait_for_css_visibility('#main_menu #'+menu_link[:id], false)
        raise "Menu-link not found for '#main_menu #'#{menu_link[:id]}" if link_to_click.nil?
        link_to_click.click
        # Capybara.ignore_hidden_elements = true
        assert_ajax_success_and_test_for_access_denied
        close_possible_popup_message                                            # close potential popup message from call
      rescue Exception=>e
#        save_and_open_screenshot
        raise "Exception #{e.class}: #{e.message}\nProcessing click on #{menu_link[:id]} with menu nodes #{menu_link[:click_tree_ids]}"
      end

    end

  end




end