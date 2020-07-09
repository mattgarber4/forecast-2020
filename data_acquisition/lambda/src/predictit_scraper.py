from selenium import webdriver
import re
from datetime import datetime
import time
import psycopg2
import os
import boto3
import pandas as pd
from io import StringIO
from psycopg2 import sql

# get ids from s3
s3 = boto3.client('s3',
                  aws_access_key_id = os.environ.get('AWS_ACCESS_KEY_ID'),
                  aws_secret_access_key = os.environ.get('AWS_SECRET_ACCESS_KEY'))
csv_obj = s3.get_object(Bucket=os.environ.get('AWS_BUCKET_NAME'), Key='predictit_codes.csv')
body = csv_obj['Body']
csv_string = body.read().decode('utf-8')


pd_ids = pd.read_csv(StringIO(csv_string))

# set options for chrome driver
chrome_options = webdriver.ChromeOptions()
chrome_options.add_argument('--headless')
chrome_options.add_argument('--no-sandbox')
chrome_options.add_argument('--disable-gpu')
chrome_options.add_argument('--window-size=1280x1696')
chrome_options.add_argument('--user-data-dir=/tmp/user-data')
chrome_options.add_argument('--hide-scrollbars')
chrome_options.add_argument('--enable-logging')
chrome_options.add_argument('--log-level=0')
chrome_options.add_argument('--v=99')
chrome_options.add_argument('--single-process')
chrome_options.add_argument('--data-path=/tmp/data-path')
chrome_options.add_argument('--ignore-certificate-errors')
chrome_options.add_argument('--homedir=/tmp')
chrome_options.add_argument('--disk-cache-dir=/tmp/cache-dir')
chrome_options.add_argument(
    'user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/61.0.3163.100 Safari/537.36')
chrome_options.binary_location = os.getcwd() + "/bin/headless-chromium"


# parsing function
def get_line(el):
    party = el.find_element_by_css_selector("span.market-contract-horizontal-v2__title-text").get_attribute("innerHTML")
    party = party[0:1]
    price = el.find_element_by_css_selector("span.market-contract-horizontal-v2__current-price-display").text
    price = int(re.sub('[^0-9]','', price))
    return {'party': party, 'price': price}

# handler to get data from market
def get_market_data(webdr, _id, state, secs = 1):
    if secs > 10:
        return [{
            'party': None,
            'price': None,
            'state': state,
            'time': datetime.now()
        }]
    
    url = 'https://www.predictit.org/markets/detail/' + str(_id)
    webdr.get(url)
    time.sleep(secs)
    
    els = webdr.find_elements_by_css_selector("div.market-contract-horizontal-v2")
    if len(els) < 1:
        print("trying assumed time error")
        return get_market_data(webdr, _id, state, secs + 1)
    else:
        out = [get_line(el) for el in els]
        t = datetime.now()
        for rec in out:
            rec['state'] = state
            rec['time'] = t
        return out

# lambda handler!!!
def lambda_handler(event, context):
    query = sql.SQL("""insert into predictit.prices_test (party, price, state, time) values (%s, %s, %s, %s)""")
    # open connection to database
    conn = psycopg2.connect(user=os.environ.get('AWS_RDS_USER'),
                                  password=os.environ.get("AWS_RDS_PASSWORD"),
                                  host=os.environ.get("AWS_RDS_HOST"),
                                  port="5432",
                                  database="postgres")


    # headless web driver
    wd = webdriver.Chrome(chrome_options=chrome_options)
    with conn.cursor() as cursor:
        for index, row in pd_ids.iterrows():
            out = get_market_data(wd, _id = int(row['id']), state = row['state'])
            for r in out:
                cursor.execute(query,
                               (r['party'], r['price'], r['state'], r['time']))

            print('Successfully loaded ' + row['state'])


    # close resources
    wd.quit()
    conn.commit()
    conn.close()

