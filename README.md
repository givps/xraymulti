# XRAY MULTI

<h2 align="center"> Supported Linux Distribution</h2>
<p align="center"><img src="https://d33wubrfki0l68.cloudfront.net/5911c43be3b1da526ed609e9c55783d9d0f6b066/9858b/assets/img/debian-ubuntu-hover.png"></p> 
<p align="center"><img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%209&message=Stretch&color=purple"> <img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%2010&message=Buster&color=purple">  <img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=Ubuntu%2018&message=Lts&color=red"> <img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=Ubuntu%2020&message=Lts&color=red">
</p>


<p align="center"><img src="https://img.shields.io/badge/Service-XRAY_VLESS-success.svg">  <img src="https://img.shields.io/badge/Service-XRAY_VMESS-success.svg">  <img src="https://img.shields.io/badge/Service-XRAY_TROJAN-success.svg"> <img src= "https://img.shields.io/badge/Service-Websocket-success.svg"> <img src= "https://img.shields.io/badge/Service-GRPC-success.svg"> <img src= "https://img.shields.io/badge/Service-Shadowsocks-success.svg">  

# Required VPS is still fresh (MUST) / have never installed anything
<br>
- If you install the Script twice, you need to rebuild the VPS to factory settings, in the VPS provider panel<br>
- DOMAIN (MUST) / Random from Script<br>
- DEBIAN 9/10<br>
- Ubuntu 18/20 LTS<br>
- CPU MIN 1 CORE<br>
- RAM 1GB<br>
- (Recommendation) Ubuntu 18 / 20 LTS (STABLE to use)
<br>

# XRAY PORT
- VLESS WS         : **433/80**
- VLESS GRPC       : **433/80**
- VMESS WS         : **433/80**
- VMESS GRPC       : **433/80**
- TROJAN WS        : **433/80**
- TROJAN GRPC      : **433/80**
- TROJAN TCP       : **2083**
- SHADOWSOCKS WS   : **433/80**
- SHADOWSOCKS GRPC : **433/80**

# install
- (debian) please update first
```
apt update && apt upgrade -y && reboot
```
- (ubuntu) directly install

```
sysctl -w net.ipv6.conf.all.disable_ipv6=1 && sysctl -w net.ipv6.conf.default.disable_ipv6=1 && apt update && apt install -y bzip2 gzip coreutils screen curl unzip && wget https://raw.githubusercontent.com/givps/xraymulti/master/setup.sh && chmod +x setup.sh && ./setup.sh && chmod +x setup.sh && sed -i -e 's/\r$//' setup.sh && screen -S setup ./setup.sh
```

# Telegram
[![Telegram-grup](https://img.shields.io/badge/Telegram-blue)](https://t.me/givps_com/)

# ATTENTION (MUST READ) CAREFULLY
- PROHIBITED FOR SALE BECAUSE I GET FREE FROM THE INTERNET
- DATA SECURITY / YOUR USE HISTORY ON THE INTERNET IS NOT MY RESPONSIBILITY AS A SCRIPT PROVIDER
- ALL YOUR DATA / USAGE HISTORY ON THE INTERNET ONLY VPS NETWORK PROVIDERS MANAGE IT AND (FBI) maybe
- USE IT WISELY THEN YOU WILL AVOID PROBLEMS
- WATCHING ADULT FILM IS YOUR OWN RESPONSIBILITY

# FINAL MESSAGE
- THANK YOU FOR TAKING THE TIME TO READ AND SORRY IF THERE ARE IMPACT WORDS
- BECAUSE I AM ALSO A HUMAN WHO DOESN'T ESCAPE FROM MISTAKES
- if you find an error, create a trouble ticket on : https://github.com/givps/xraymulti/issues
- script source : https://github.com/fisabiliyusri/Mantap

<p align="center">
<a href="https://opensource.org/licenses/MIT"> <img src="https://img.shields.io/badge/License-MIT-yellow.svg" style="max-width:200%;"> <a><img src="https://img.shields.io/badge/givps.com-blue" style="max-width:200%;">

