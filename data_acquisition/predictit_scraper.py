from selenium import webdriver
import re

wd = webdriver.Chrome(executable_path='C:/Users/mattg/Documents/forecast-2020/data_acquisition/chromedriver.exe')
wd.get("https://www.predictit.org/markets/detail/5599")


def get_line(el):
    party = el.find_element_by_css_selector("span.market-contract-horizontal-v2__title-text").get_attribute("innerHTML")
    party = party[0:1]
    price = el.find_element_by_css_selector("span.market-contract-horizontal-v2__current-price-display").text
    price = int(re.sub('[^0-9]','', price))
    return {'party': party, 'price': price}
    
    

els = wd.find_elements_by_css_selector("div.market-contract-horizontal-v2")
for el in els:
    print(get_line(el))
