Cost Explorer: https://aws-ciw-readonly.amazon.com/cost-management/home?spoofAccountId=XXXX 
Billing Console: https://aws-bpc-readonly-midway.corp.amazon.com/billing/home?spoofAccountId=XXXX


# funplus： FunPlus International AG
https://aws-ciw-readonly.amazon.com/cost-management/home?spoofAccountId=044441774960

# netease:  NetEase, Inc.
https://aws-ciw-readonly.amazon.com/cost-management/home?spoofAccountId=918956054262 

# zixun: Fujian Zixun Information Technology Co.,Ltd
https://aws-ciw-readonly.amazon.com/cost-management/home?spoofAccountId=029407930094


Solutions Architect,Technical Account Manager,Customer Solutions Manager


## 安装 Python
## 安装最新的 PowerShell
https://github.com/PowerShell/PowerShell/releases/download/v7.4.4/PowerShell-7.4.4-win-x64.msi
https://github.com/PowerShell/PowerShell/releases/download/v7.4.4/PowerShell-7.4.4-win-x86.msi


# Windows执行
## 生成报告
./InstallAndRunGSR.ps1 -BatchMode -BatchFile 'D:\Customers-List.csv' -GsrInstallationLocation 'D:\'
 
## 发送报告
python.exe D:\GSR-sendmail\SendEmail.py -hfile 'D:\GSR-sendmail\Dear Account Team.html' -rdir 'D:\GSR' -clst 'D:\Customers-List.csv'








