require "test_helper"

class DbaGeneralPwTest < PlaywrightSystemTestCase

  test "Start page" do
    menu_call('DBA general', 'menu_env_start_page')
    content = @page.content
    assert content['Current database']
    assert content['Server versions']
    assert content['Client versions']
    assert content['Instance data']
    assert content['Usage of Oracle management packs by Panorama']
    assert content['Handling hints']
  end
end

