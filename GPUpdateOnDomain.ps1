# GPUpdateOnDomain.ps1
# Runs GPUpdate when connected to a Domain Authenticated network.
# Suitable for:
#   - Corporate LAN connections
#   - FortiClient VPN connections
#
# Scheduled Task:
#
# Program:
#   powershell.exe
#
# Arguments:
#   -ExecutionPolicy Bypass -File "C:\SoftwareDeployment\GPUpdate\GPUpdateOnDomain.ps1"

$LogFolder = "C:\Windows\Temp\GPUpdate"
$LogFile = Join-Path $LogFolder "GPUpdateVPN.log"

# Create log folder if required
if (!(Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message
    )

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Add-Content -Path $LogFile `
        -Value "$TimeStamp - $Message" `
        -Encoding UTF8
}

try {

    Write-Log "====================================================="
    Write-Log "Script started."
    Write-Log "User: $env:USERNAME"
    Write-Log "Domain: $env:USERDOMAIN"

    # Detect a domain-authenticated connection
    $Profiles = Get-NetConnectionProfile | Where-Object {
        $_.NetworkCategory -eq "DomainAuthenticated"
    }

    if (-not $Profiles) {
        Write-Log "No Domain Authenticated network detected. GPUpdate skipped."
        exit 0
    }

    foreach ($Profile in $Profiles) {
        Write-Log "Detected Domain Authenticated network: $($Profile.Name)"
    }

    #
    # Capture GPResult BEFORE
    #

    Write-Log "Capturing GPResult BEFORE update."
	
<# 	$BeforeComputer = gpresult /scope user /r 2>&1 |
	ForEach-Object {

		$line = [string]$_

		Write-Log "================================================"
		Write-Log $line

		foreach ($char in $line.ToCharArray()) {
			Write-Log ("'{0}' = U+{1:X4}" -f $char, [int][char]$char)
		}

		$line
	}
		
    $BeforeUser = gpresult /scope user /r 2>&1 |
	ForEach-Object {

		$line = [string]$_

		Write-Log "================================================"
		Write-Log $line

		foreach ($char in $line.ToCharArray()) {
			Write-Log ("'{0}' = U+{1:X4}" -f $char, [int][char]$char)
		}

		$line
	} #>
	
	$BeforeComputer = gpresult /scope user /r 2>&1 |
	ForEach-Object {
		$_ -replace '[^\x20-\x7E]', ''
		}
	
    $BeforeUser = gpresult /scope user /r 2>&1 |
	ForEach-Object {
		$_ -replace '[^\x20-\x7E]', ''
		}

    #
    # Run GPUpdate
    #

    Write-Log "Running gpupdate /force"
		
	Start-Sleep -Seconds 7
	
	$User = (Get-CimInstance Win32_ComputerSystem).UserName

	if ($User) {
		$UserName = $User.Split('\')[-1]
		msg $UserName /time:10 "SATO EU IT: SATO Domain Detected. Group Policy Applying."
	}	
	
    $Process = Start-Process `
    -FilePath "cmd.exe" `
    -ArgumentList '/c echo N^|gpupdate /force /wait:60' `
    -Wait `
    -PassThru `
    -WindowStyle Hidden
	
	Start-Sleep -Seconds 60

    Write-Log "GPUpdate completed. Exit code: $LASTEXITCODE"

    if ($LASTEXITCODE -ne 0) {
        Write-Log "WARNING: GPUpdate returned non-zero exit code."
    }

    #
    # Capture GPResult AFTER
    #

    Write-Log "Capturing GPResult AFTER update."

<#     $AfterComputer = gpresult /scope user /r 2>&1 |
	ForEach-Object {

		$line = [string]$_

		Write-Log "================================================"
		Write-Log $line

		foreach ($char in $line.ToCharArray()) {
			Write-Log ("'{0}' = U+{1:X4}" -f $char, [int][char]$char)
		}

		$line
	}
		
    $AfterUser = gpresult /scope user /r 2>&1 |
	ForEach-Object {

		$line = [string]$_

		Write-Log "================================================"
		Write-Log $line

		foreach ($char in $line.ToCharArray()) {
			Write-Log ("'{0}' = U+{1:X4}" -f $char, [int][char]$char)
		}

		$line
	} #>
	
	$AfterComputer =gpresult /scope user /r 2>&1 |
	ForEach-Object {
		$_ -replace '[^\x20-\x7E]', ''
		}
	
	$AfterUser =gpresult /scope user /r 2>&1 |
	ForEach-Object {
		$_ -replace '[^\x20-\x7E]', ''
		}	

    #
    # Compare Computer Policies
    #

    $ComputerChanges = Compare-Object `
        -ReferenceObject $BeforeComputer `
        -DifferenceObject $AfterComputer

    if ($ComputerChanges) {

        Write-Log "==== COMPUTER POLICY CHANGES DETECTED ===="

        foreach ($Change in $ComputerChanges) {

            if ($Change.SideIndicator -eq "=>") {
                Write-Log "COMPUTER ADDED: $($Change.InputObject)"
            }

            if ($Change.SideIndicator -eq "<=") {
                Write-Log "COMPUTER REMOVED: $($Change.InputObject)"
            }
        }
    }
    else {

        Write-Log "No Computer Policy changes detected."
    }

    #
    # Compare User Policies
    #

    $UserChanges = Compare-Object `
        -ReferenceObject $BeforeUser `
        -DifferenceObject $AfterUser

    if ($UserChanges) {

        Write-Log "==== USER POLICY CHANGES DETECTED ===="

        foreach ($Change in $UserChanges) {

            if ($Change.SideIndicator -eq "=>") {
                Write-Log "USER ADDED: $($Change.InputObject)"
            }

            if ($Change.SideIndicator -eq "<=") {
                Write-Log "USER REMOVED: $($Change.InputObject)"
            }
        }
    }
    else {

        Write-Log "No User Policy changes detected."
    }

    Write-Log "Script completed successfully."
}
catch {

    Write-Log "ERROR: $($_.Exception.Message)"
    Write-Log "ERROR LINE: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Log "Script terminated unexpectedly."
}
