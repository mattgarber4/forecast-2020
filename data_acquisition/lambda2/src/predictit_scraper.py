from selenium import webdriver
import re
from datetime import datetime
import time
import psycopg2
import os
import boto3
import csv
from io import StringIO
from psycopg2 import sql
import shutil

BIN_DIR = "/tmp/bin/" + str(os.environ.get('FN_NUM'))
CURR_BIN_DIR = os.getcwd() + "/bin"

# get ids from s3
s3 = boto3.client('s3',
                  aws_access_key_id = os.environ.get('ACCESS_KEY_ID'),
                  aws_secret_access_key = os.environ.get('SECRET_ACCESS_KEY'))
csv_obj = s3.get_object(Bucket=os.environ.get('AWS_BUCKET_NAME'), Key=os.environ.get('STATE_KEY_TABLE_NAME'))
body = csv_obj['Body']
csv_string = body.read().decode('utf-8')

pd_ids = []
for row in csv.reader(StringIO(csv_string)):
    pd_ids.append((row[0], row[1]))

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
chrome_options.binary_location = os.path.join(BIN_DIR + "/headless-chromium")




def _init_bin(executable_name):
    start = time.clock()
    if not os.path.exists(BIN_DIR):
        print("Creating bin folder")
        os.makedirs(BIN_DIR)
    print("Copying binaries for " + executable_name + " in /tmp/bin")
    currfile = os.path.join(CURR_BIN_DIR, executable_name)
    newfile = os.path.join(BIN_DIR, executable_name)
    shutil.copy2(currfile, newfile)
    print("Giving new binaries permissions for lambda")
    os.chmod(newfile, 0o775)
    elapsed = time.clock() - start
    print(executable_name + " ready in " + str(elapsed) + "s.")


_init_bin('chromedriver')
_init_bin('headless-chromium')

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
    s = "insert into predictit." + os.environ.get('TABLE_NAME') + " (party, price, state, time) values (%s, %s, %s, %s)"
    query = sql.SQL(s)
    # open connection to database
    conn = psycopg2.connect(user=os.environ.get('AWS_RDS_USER'),
                                  password=os.environ.get("AWS_RDS_PASSWORD"),
                                  host=os.environ.get("AWS_RDS_HOST"),
                                  port="5432",
                                  database="postgres")


    # headless web driver
    wd = webdriver.Chrome(chrome_options=chrome_options, executable_path=os.path.join(BIN_DIR + '/chromedriver'))
    with conn.cursor() as cursor:
        for pair in pd_ids:
            state = re.sub('[^-A-Z0-9]', '', pair[0])
            _id = re.sub('[^-A-Z0-9]', '', pair[1])
            out = get_market_data(wd, _id = int(_id), state = state)
            for r in out:
                cursor.execute(query,
                               (r['party'], r['price'], state, r['time']))

            print('Successfully loaded ' + pair[0].strip())


    # close resources
    wd.quit()
    conn.commit()
    conn.close()

