param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    
    [Parameter(Mandatory=$false)]
    [string]$Title = "Notification",
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("toast", "balloon", "messagebox", "console", "all")]
    [string]$Method = "all",
    
    [Parameter(Mandatory=$false)]
    [switch]$DebugMode
)

# Debug output function
function Write-DebugInfo {
    param([string]$Message)
    if ($DebugMode) {
        Write-Host "[DEBUG] $Message" -ForegroundColor Magenta
    }
}

# Toast notification method
function Send-ToastNotification {
    param([string]$Message, [string]$Title)
    
    try {
        Write-DebugInfo "Attempting Toast notification..."
        
        # Check Windows version
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10) {
            throw "Requires Windows 10 or higher"
        }
        
        # Try multiple AppIds
        $appIds = @(
            "Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy!App",
            "Microsoft.WindowsTerminal_8wekyb3d8bbwe!App",
            "Windows.SystemToast.Suggested",
            "Microsoft.PowerShell",
            "PowerShell.ISE"
        )

        foreach ($appId in $appIds) {
            try {
                Write-DebugInfo "Trying AppId: $appId"
                
                # Load Windows Runtime
                [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
                [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
                
                # Create XML template for Toast notification
                $toastXml = @"
<toast>
    <visual>
        <binding template="ToastGeneric">
            <text>$Title</text>
            <text>$Message</text>
        </binding>
    </visual>
    <actions>
        <action content="OK" arguments="ok" />
    </actions>
</toast>
"@
                
                # Create and send notification
                $xmlDoc = New-Object Windows.Data.Xml.Dom.XmlDocument
                $xmlDoc.LoadXml($toastXml)
                $toast = [Windows.UI.Notifications.ToastNotification]::new($xmlDoc)
                $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId)
                $notifier.Show($toast)

                if ($DebugMode) {
                    Write-Host "✅ Toast notification sent: $Message" -ForegroundColor Green
                }
                return $true
            } catch {
                Write-DebugInfo "AppId '$appId' failed: $($_.Exception.Message)"
                continue
            }
        }
        
        throw "All AppIds failed"
        
    } catch {
        Write-DebugInfo "Toast notification failed: $($_.Exception.Message)"
        return $false
    }
}

# Balloon notification method
function Send-BalloonNotification {
    param([string]$Message, [string]$Title, [int]$Duration = 5000)
    
    try {
        Write-DebugInfo "Attempting balloon notification..."
        
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Create notification icon
        $icon = [System.Drawing.SystemIcons]::Information
        
        # Create NotifyIcon
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = $icon
        $notifyIcon.Visible = $true
        $notifyIcon.Text = "PowerShell Notification"

        # Show balloon notification
        $notifyIcon.ShowBalloonTip($Duration, $Title, $Message, [System.Windows.Forms.ToolTipIcon]::Info)
        
        if ($DebugMode) {
            Write-Host "✅ Balloon notification sent: $Message" -ForegroundColor Green
        }
        
        # Wait for notification display
        Start-Sleep -Milliseconds ($Duration + 1000)
        
        # Clean up resources
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        
        return $true
        
    } catch {
        Write-DebugInfo "Balloon notification failed: $($_.Exception.Message)"
        return $false
    }
}

# MessageBox notification method
function Send-MessageBoxNotification {
    param([string]$Message, [string]$Title)
    
    try {
        Write-DebugInfo "Attempting MessageBox notification..."
        
        Add-Type -AssemblyName System.Windows.Forms
        [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
        
        if ($DebugMode) {
            Write-Host "✅ MessageBox notification displayed: $Message" -ForegroundColor Green
        }
        return $true
        
    } catch {
        Write-DebugInfo "MessageBox notification failed: $($_.Exception.Message)"
        return $false
    }
}

# Console notification method
function Send-ConsoleNotification {
    param([string]$Message, [string]$Title)
    
    if ($DebugMode) {
        Write-Host ""
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host "📢 $Title" -ForegroundColor Yellow
        Write-Host "-------------------------------" -ForegroundColor Cyan
        Write-Host "$Message" -ForegroundColor Green
        Write-Host "===============================" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "✅ Console notification displayed: $Message" -ForegroundColor Green
    }
    return $true
}

# msg.exe notification method
function Send-MsgNotification {
    param([string]$Message, [string]$Title)
    
    try {
        Write-DebugInfo "Attempting msg.exe notification..."
        
        $msgResult = & msg.exe $env:USERNAME /TIME:10 "$Title - $Message" 2>&1
        if ($LASTEXITCODE -eq 0) {
            if ($DebugMode) {
                Write-Host "✅ msg.exe notification sent: $Message" -ForegroundColor Green
            }
            return $true
        } else {
            throw "msg.exe failed: $msgResult"
        }
    } catch {
        Write-DebugInfo "msg.exe notification failed: $($_.Exception.Message)"
        return $false
    }
}

# Main logic
Write-DebugInfo "Starting to send notification: $Message"
Write-DebugInfo "Method: $Method"

# Check WSL environment
if ($env:WSL_DISTRO_NAME) {
    Write-Warning "WSL environment detected, Toast notifications may not display properly"
}

$success = $false

switch ($Method.ToLower()) {
    "toast" {
        $success = Send-ToastNotification -Message $Message -Title $Title
    }
    "balloon" {
        $success = Send-BalloonNotification -Message $Message -Title $Title
    }
    "messagebox" {
        $success = Send-MessageBoxNotification -Message $Message -Title $Title
    }
    "console" {
        $success = Send-ConsoleNotification -Message $Message -Title $Title
    }
    "all" {
        if ($DebugMode) {
            Write-Host "Trying multiple notification methods..." -ForegroundColor Cyan
            Write-Host ""
        }
        
        # Try Toast notification
        if ($DebugMode) {
            Write-Host "[1/5] Trying Toast notification..." -ForegroundColor Yellow
        }
        if (Send-ToastNotification -Message $Message -Title $Title) {
            $success = $true
        } else {
            # Try balloon notification
            if ($DebugMode) {
                Write-Host "[2/5] Trying balloon notification..." -ForegroundColor Yellow
            }
            if (Send-BalloonNotification -Message $Message -Title $Title) {
                $success = $true
            } else {
                # Try msg.exe
                if ($DebugMode) {
                    Write-Host "[3/5] Trying msg.exe..." -ForegroundColor Yellow
                }
                if (Send-MsgNotification -Message $Message -Title $Title) {
                    $success = $true
                } else {
                    # Try MessageBox
                    if ($DebugMode) {
                        Write-Host "[4/5] Trying MessageBox..." -ForegroundColor Yellow
                    }
                    if (Send-MessageBoxNotification -Message $Message -Title $Title) {
                        $success = $true
                    } else {
                        # Finally use console
                        if ($DebugMode) {
                            Write-Host "[5/5] Using console notification..." -ForegroundColor Yellow
                        }
                        $success = Send-ConsoleNotification -Message $Message -Title $Title
                    }
                }
            }
        }
    }
}

if ($success) {
    if ($DebugMode) {
        Write-Host ""
        Write-Host "Notification sending completed!" -ForegroundColor Green
    }
} else {
    Write-Error "All notification methods failed"
    exit 1
}