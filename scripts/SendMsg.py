# -*- coding: utf-8 -*-
"""
@Time ： 2021/6/12 16:27
@Auth ： Twinzo1
@File ：SendMsg.py
@IDE ：PyCharm
@Motto：ABC(Always Be Coding)
@@Version: V1.0
@Description: 
"""
import os
from dingtalkchatbot.chatbot import DingtalkChatbot, is_not_null_and_blank_str, ActionCard, FeedLink, CardItem

class SendMsg:
    def __init__(self, dd_token, dd_secret):
        self.webhook = 'https://oapi.dingtalk.com/robot/send?access_token=' + dd_token
        self.secret = dd_secret

    def msg(self, msg_title, msg_content):
        # 可选：创建机器人勾选“加签”选项时使用
        xiaoding = DingtalkChatbot(self.webhook, secret=self.secret)
        xiaoding.send_markdown(title=msg_title, text=msg_content)


if __name__ == '__main__':
    # 填写钉钉token和secret
    token = ""
    secret = ""
    t = SendMsg(token, secret)
    # 填写标题和内容
    title = ""
    content = ""
    t.msg(title, content)
