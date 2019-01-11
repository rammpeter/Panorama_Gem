require "test_helper"

class GlobalMenuTest < ApplicationSystemTestCase
  setup do
    register_test_start_in_log
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
        @menu_links << {id: menu_link[:id], click_tree_ids: click_tree_ids}
      else                                                                      # Menu is node
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
segment_statistics = false
      menu_link[:click_tree_ids].each do |menu_node_id|
        begin
          #menu_node = page.find(:css, '#main_menu #'+menu_node_id, visible: false)              # find menu node by id again
          menu_node = page.find(:css, '#main_menu #'+menu_node_id, visible: true)              # find menu node by id again
          if !menu_node.visible?
            puts "Sleeping waiting for menu node '#main_menu ##{menu_node_id}' to become visible"
            sleep 1
            raise "Menu node '#main_menu ##{menu_node_id}' not visible" if !menu_node.visible?
          end
          #puts "hover #{menu_node.text}"
          sleep 1
          #if menu_node.text['Analyses / statistics']
          #  save_screenshot('analyses.png')
          #end
          #if menu_node.text['Segment Statistics']
          #  save_screenshot('before.png')
          #  segment_statistics = true
          #end
#puts "before hover" if segment_statistics

          menu_node.hover
#puts "after hover" if segment_statistics

#          if segment_statistics
#            puts "After menu_node.text = #{menu_node.text}"
#            save_screenshot('after.png')
#            puts "Searching '#{menu_link[:id]}'"
#          end
        rescue Exception=>e
          raise "Exception #{e.class}: #{e.message}\nProcessing hover on menues of #{menu_link[:id]} at menu node #{menu_node_id}"
        end
      end
#puts "before click" if segment_statistics

      begin
        # Capybara.ignore_hidden_elements = false
        link_to_click = page.find(:css, '#main_menu #'+menu_link[:id], visible: false)
        if !link_to_click.visible?
          puts "Sleeping waiting for menu link '#main_menu ##{menu_link[:id]}' to become visible"
          sleep 1
          save_screenshot('waiting_for.png')
          raise "Menu-link not visible '#main_menu #'#{menu_link[:id]}"   if !link_to_click.visible?
        end
        raise "Menu-link not found for '#main_menu #'#{menu_link[:id]}" if link_to_click.nil?
        #puts "click #{link_to_click.text}"
        link_to_click.click
        # Capybara.ignore_hidden_elements = true
        assert_ajax_success_or_access_denied
        close_possible_popup_message                                            # close potential popup message from call
      rescue Exception=>e
#        save_and_open_screenshot
        raise "Exception #{e.class}: #{e.message}\nProcessing click on #{menu_link[:id]} with menu nodes #{menu_link[:click_tree_ids]}"
      end

    end

  end




end