Set sh = CreateObject("WScript.Shell")
sh.Run "cmd /c powershell -NoProfile -ExecutionPolicy Bypass -File ""D:/deepseek/scripts/api-balance-widget.ps1"" > ""C:/CodexTemp/widget-run.log"" 2>&1", 0, False
