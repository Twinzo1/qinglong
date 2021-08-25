# -*- coding: utf-8 -*-
"""
@Time ： 2021/6/30 8:08
@Auth ： Twinzo1
@File ：SCUTracing.py
@IDE ：PyCharm
@Motto：ABC(Always Be Coding)
@@Version: V1.02
@Description: 
"""
import requests
import json
import random
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


class SCUTracing:
    def __init__(self, your_email, your_password):
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) '
                          'Chrome/78.0.3904.116 Safari/537.36',
        }
        self.url_prefix = "http://120.77.14.141"
        self.name = your_email
        self.password = your_password
        self.account_name = ""
        self.cookie = self.get_cookie()
        self.emotid = 8
        self.content = ""
        self.formhash = ""
        self.signin_state = ""

    def login(self):
        url = self.url_prefix + "/member.php?mod=logging&action=login&loginsubmit=yes&loginhash=LPmlE&inajax=1"
        data = {
            'loginfield': 'username',
            'referer': 'http://120.77.14.141/portal.php?mod=topic&topicid=4',
            'username': self.name,
            'password': self.password,
            'questionid': '0',
            'answer': ''
        }
        response = requests.post(url, headers=self.headers, data=data)

        res_text = response.text
        name_index_start = res_text.index('欢迎您回来')
        name_index_end = res_text.index('现在将')
        self.account_name = res_text[name_index_start + 6:name_index_end - 1]

        if "欢迎您回来" in res_text:
            return response
        else:
            print("登录失败")
            return

    def get_cookie(self):
        cookie = requests.utils.dict_from_cookiejar(self.login().cookies)
        return cookie

    def get_user_data(self):
        url = self.url_prefix + "/home.php?mod=spacecp&ac=credit&showcredit=1"
        response = requests.post(url, headers=self.headers, cookies=self.cookie)

        doc = pq(response.text)
        coin = doc('li')
        ret = {'账号名': self.account_name}
        i = 0
        for li_html in coin.items():
            if "xi1 cl" in str(li_html):
                coin_txt = li_html.text()
                ret_msg = coin_txt
                i = 1
                continue
            if i != 0:
                ret_msg += "\n" + li_html.text().replace('\n', '')
                i += 1
            if i == 4:
                break

        ret.update(escape2dict(ret_msg))
        return ret

    def check_in(self):
        self.get_emotion()
        self.get_formhash()

        url = self.url_prefix + "/plugin.php?id=dc_signin:sign&inajax=1"
        data = {
            'formhash': self.formhash,
            'signsubmit': 'yes',
            'handlekey': 'signin',
            'emotid': self.emotid,
            'content': self.content,
        }
        response = requests.post(url, headers=self.headers, data=data, cookies=self.cookie)
        doc = pq(response.content, parser="html")
        self.signin_state = doc('root').text().split("('")[1].split("',")[0]
        if "成功" in self.signin_state:
            ret = self.get_user_data()
        else:
            ret = self.get_signin_data()
        ret.update({'签到': self.signin_state})

        return ret

    def get_formhash(self):
        url = self.url_prefix + "/portal.php?mod=topic&topicid=4"
        response = requests.get(url, headers=self.headers, cookies=self.cookie)
        doc = pq(response.text)
        input_list = doc('input')
        for li in input_list.items():
            if li.attr('name') == 'formhash':
                self.formhash = li.attr('value')
                return

    def get_emotion(self):
        url = self.url_prefix + "/plugin.php?id=dc_signin:sign&infloat=yes&handlekey=sign&inajax=1&ajaxtarget=fwin_content_sign"
        response = requests.get(url, headers=self.headers, cookies=self.cookie)
        doc = pq(response.content, parser="html")

        emotion = doc('.dcsignin2')
        emotion_dict = {}
        for em in emotion.items():
            emotion_dict[str(em('img').attr('id').replace('emot_', ''))] = em('img').attr('title')
        random_emotid = random.randint(1, 10)
        if not emotion_dict:
            return
        self.emotid = random_emotid
        self.content = emotion_dict[str(random_emotid)]

    def get_signin_data(self):
        url = self.url_prefix + "/plugin.php?id=dc_signin&action=index"

        response = requests.get(url, headers=self.headers, cookies=self.cookie)
        doc = pq(response.text)
        signmsg = doc('div .mytips')
        print(repr(signmsg.text()))
        return escape2dict(signmsg.text())
        # doc = pq(response.text)


def main():
    account = {
        "zzs11": {"name": "",
                  "password": ""},
    }
    msg_content = "#### **车队论坛登录**\n\n-------\n"
    id = 0
    for key in account:
        right_com = SCUTracing(account[key]['name'], account[key]['password'])
        data_dict = right_com.check_in()
        id += 1
        msg_content = "".join((msg_content, "##### <font color=#87CEEB>**账号", str(id), "**</font>\n\n"))
        for key in data_dict:
            msg_content = "".join((msg_content, "#### **车队论坛登录**", "\n\n", "-------", "\n",
                       "##### <font color=#87CEEB>**账号", str(id), "**</font>\n\n"))
        msg_content += "----------\n"

    try:
        import SendMsg
        send = True
    except:
        send = False
        pass

    if send:
        token = os.getenv('DD_SIGN_IN_BOT_TOKEN')
        secret = os.getenv('DD_SIGN_IN_BOT_SECRET')
        send = SendMsg.SendMsg(token, secret)
        send.msg("车队论坛登录", msg_content)
    print(msg_content)


if __name__ == '__main__':
    main()
