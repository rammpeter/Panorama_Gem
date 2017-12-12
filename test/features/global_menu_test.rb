require "test_helper"

class GlobalMenuTest < Capybara::Rails::TestCase
  include MenuHelper

  def click_menu_entries(menu_ul, click_tree)
    # Iterate menues
    menu_ul.all(:xpath, './li').each do |menu_li|
      next_menu_uls = menu_li.all(:xpath, './ul')
      menu_link = menu_li.find(:xpath, './a')

      if next_menu_uls.count == 0                                               # Menu is item
        puts "Item #{menu_link.text}"
        click_tree.each do |menu_node|
          puts "hover #{menu_node.text}"
          menu_node.hover
          sleep(0.5)
        end
        menu_link.click
#        save_and_open_screenshot
#        wait_for_ajax
#        save_and_open_screenshot
      else                                                                      # Menu is node
        puts "Menu #{menu_link.text}"
        click_menu_entries(next_menu_uls[0], click_tree.clone << menu_link)     # process items of node
      end
    end
  end

  test "All menu entries" do

#    login_and_menu_call('DBA general', 'menu_env_start_page')

    login_until_menu

    top_ul = page.find(:css, '#main_menu > .sf-menu')

    # Does not work currently
    #click_menu_entries(top_ul, [])
  end


end
