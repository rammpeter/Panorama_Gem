require "test_helper"

class GlobalMenuTest < Capybara::Rails::TestCase
  include MenuHelper

  def get_menu_entries(menu_ul, click_tree_ids)
    # Iterate menues
    menu_ul.all(:xpath, './li').each do |menu_li|
      next_menu_uls = menu_li.all(:xpath, './ul')
      menu_link = menu_li.find(:xpath, './a')

      if next_menu_uls.count == 0                                               # Menu is item
        @menu_links << {id: menu_link[:id], click_tree_ids: click_tree_ids}
      else                                                                      # Menu is node
        get_menu_entries(next_menu_uls[0], click_tree_ids.clone << menu_link[:id])              # process items of node
      end
    end
  end


  def click_menu_entries(menu_ul, click_tree_ids)
    # Iterate menues
    menu_ul.all(:xpath, './li').each do |menu_li|
      next_menu_uls = menu_li.all(:xpath, './ul')
      menu_link = menu_li.find(:xpath, './a')

      if next_menu_uls.count == 0                                               # Menu is item
        puts "Item #{menu_link.text}"
        click_tree_ids.each do |menu_node_id|
          menu_node = page.find(:css, '#main_menu #'+menu_node_id)              # find menu node by id again
          puts "hover #{menu_node.text}"
          menu_node.hover
          sleep(0.5)
        end
        begin
          menu_li.find(:xpath, './a').click                                     # Load element again after opening menus and click
        rescue Exception=>e
          save_and_open_screenshot
          raise "Exception #{e.class}: #{e.message}\nclick_tree_ids = #{click_tree_ids}"
        end
#        save_and_open_screenshot
#        wait_for_ajax
#        save_and_open_screenshot
      else                                                                      # Menu is node
        puts "Menu #{menu_link.text}"
        click_menu_entries(next_menu_uls[0], click_tree_ids.clone << menu_link[:id])     # process items of node
      end
    end
  end

  test "All menu entries" do

#    login_and_menu_call('DBA general', 'menu_env_start_page')

    login_until_menu

    top_ul = page.find(:css, '#main_menu > .sf-menu')

    @menu_links = []                                                            # Hierarchic array
    get_menu_entries(top_ul, [])

    @menu_links.each do |menu_link|
      menu_link[:click_tree_ids].each do |menu_node_id|
        begin
          menu_node = page.find(:css, '#main_menu #'+menu_node_id)              # find menu node by id again
  #        puts "hover #{menu_node.text}"
          menu_node.hover
        rescue Exception=>e
#        save_and_open_screenshot
          raise "Exception #{e.class}: #{e.message}\nProcessing hover on menues of #{menu_link[:id]} at menu node #{menu_node_id}"
        end
        sleep(0.5)
      end
      begin
        click_link = page.find(:css, '#main_menu #'+menu_link[:id])
#        puts "click #{menu_node.text}"
        click_link.click
      rescue Exception=>e
#        save_and_open_screenshot
        raise "Exception #{e.class}: #{e.message}\nProcessing click on #{menu_link[:id]} with menu nodes #{menu_link[:click_tree_ids]}"
      end

    end

  end


end
