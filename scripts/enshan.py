# -*- coding: utf-8 -*-
"""
@Time ： 2021/6/28 23:27
@Auth ： Twinzo1
@File ：enshan.py
@IDE ：PyCharm
@Motto：ABC(Always Be Coding)
@@Version: V2.1
@Description: 恩山论坛签到
系统环境变量设置：
账号1：
ENSHAN_USERNAME_1="zz"
ENSHAN_PASSWORD_1="**"
"""
import requests
import json
import os
from pyquery import PyQuery as pq


def escape2dict(es_str, escapes='\n'):
    """
    将下面两种形式的字符串分割为字典
    '会员时长\n5 天'
    '可用流量\n37.84 GB\n今日已用: 29.03MB'
    :param es_str: 字符串
    :param escapes: 转义符类型
    :return:
    """
    split_ret = [id.split(':', 1) for id in es_str.split('{}'.format(escapes))]
    ret_dict = {}
    flag = True
    for i, s in enumerate(split_ret):
        if len(s) == 2:
            ret_dict[str(s[0]).strip()] = s[1].strip()
            flag = True
        elif not flag:
            flag = True
        else:
            ret_dict[str(s[0]).strip()] = split_ret[i + 1][0].strip()
            flag = False
    return ret_dict


class right:
    def __init__(self, your_name, your_password):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
                          'Chrome/78.0.3904.116 Safari/537.36',
        }
        self.url_prefix = "https://www.right.com.cn/forum"
        self.name = your_name
        self.password = your_password
        self.cookie = self.get_cookie()

    def login(self):
        url = self.url_prefix + "/member.php?mod=logging&action=login&loginsubmit=yes&inajax=1"
        data = {
            'username': self.name,
            'password': self.password,
            'questionid': '0',
            'answer': ''
        }
        response = requests.post(url, headers=self.headers, data=data)
        if "欢迎您回来" in response.text:
            return response
        else:
            print("登录失败")
            return

    def get_cookie(self):
        cookie = requests.utils.dict_from_cookiejar(self.login().cookies)
        return cookie

    def get_user_data(self):
        url = self.url_prefix + "/home.php?mod=spacecp&ac=credit"
        response = requests.post(url, headers=self.headers, cookies=self.cookie)

        doc = pq(response.text)
        coin = doc('li')
        i = 0
        for li_html in coin.items():
            if "xi1 cl" in str(li_html):
                coin_txt = li_html.text()
                ret_msg = coin_txt[0:int(coin_txt.index('nb')) + 2]
                i = 1
                continue
            if i != 0:
                ret_msg += "\n" + li_html.text().replace('\n', '')
                i += 1
            if i == 3:
                break

        return escape2dict(ret_msg)
      
def get_account_2_json(usr, pwd):
    """
    将从环境变量获取的账号密码拼接成json
    :return: 字典
    """
    username = os.popen("env | grep {}".format(usr))
    password = os.popen("env | grep {}".format(pwd))
    username_list = username.read().split()
    password_list = password.read().split()
    username_dict = str2dict(";".join(username_list))
    password_dict = str2dict(";".join(password_list))
    account_dict = {}
    for usr_key, pwd_key in zip(username_dict,password_dict):
        account_dict[usr_key] = {"email": username_dict[usr_key], "password": password_dict[pwd_key]}
    return account_dict
  
def main():
    account = get_account_2_json("ENSHAN_USERNAME_", "ENSHAN _PASSWORD_")
    msg_content = "#### **恩山论坛签到**\n\n-------\n"
    id = 0
    for key in account:
        right_forum = right(account[key]['email'], account[key]['password'])
        data_dict = right_forum.get_user_data()
        id += 1
        msg_content = "".join((msg_content, "##### <font color=#87CEEB>**账号", str(id), "**</font>\n\n"))
        for key in data_dict:
            msg_content = "".join((msg_content, "<font color=#DA70D6>", key, "</font>：", data_dict[key], "\n\n"))
        msg_content += "----------\n"
        
    print(msg_content)
    # 钉钉推送消息
    token = os.getenv('DD_SIGN_IN_BOT_TOKEN')
    secret = os.getenv('DD_SIGN_IN_BOT_SECRET')
    send = SendMsg.SendMsg(token, secret)
    send.msg("恩山论坛签到", msg_content)


    
if __name__ == '__main__':
    main()
