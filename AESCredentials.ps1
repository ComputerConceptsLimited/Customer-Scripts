# Script to generate encyption key (AES-256) and use this to encrypt service
# account credentials used to access CCL Polaris / vCloud Director API
# endpoints from scheduled batch jobs in a secure manner.
#
# (c) Copyright 2017, Computer Concepts Limited - see LICENSE for license details

# Select the directory where the AES keyfile and encrypted credentials files will
# be written:
Add-Type -AssemblyName System.Windows.Forms
$FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    Description = 'Select folder to save encrypted files to'
}
$result = $FolderBrowser.ShowDialog()
if ($result -eq 'Cancel') { 
    Write-Warning "Cancel selected, script exiting"
    return
}

$Credentials = Get-Credential -Message 'Enter credentials to be encrypted'
if (!$Credentials) {
    Write-Warning "No credentials entered, script exiting"
    return
}

$UserName = $Credentials.UserName

# Build filenames
$aesfile  = $FolderBrowser.SelectedPath + '\' + $UserName + '.key'
$credfile = $FolderBrowser.SelectedPath + '\' + $UserName + '.txt'
$incscr   = $FolderBrowser.SelectedPath + '\' + $UserName + '.ps1'

# Check that we can write files to the selected folder
Try { [io.file]::OpenWrite($aesfile).close() }
Catch { Write-Warning "Unable to write to $aesfile, check file system permissions, exiting" }

# Generate new secure AES-256 key and write to disk
$aeskey = New-Object Byte[] 32      # 32 bytes x 8 bit = 256-bit AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($aeskey)
$aeskey | Out-File $aesfile

# Encrypt credentials using key and write encrypted version to disk
ConvertFrom-SecureString -SecureString $Credentials.Password | ConvertTo-SecureString | ConvertFrom-SecureString -Key $aeskey | Out-File $credfile

# Write out .ps1 script to be 'included' from other automation scripts to provide credentials
$script = "# Change locations of .key and .txt files if necessary below:`r`n"
$script += "try {`r`n"
$script += "`$key = Get-Content $aesfile`r`n"
$script += "`$pass = Get-Content $credfile | ConvertTo-SecureString -Key `$key`r`n"
$script += "`$$UserName = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, `$pass`r`n"
$script += "Remove-Variable key`r`n"
$script += "Remove-Variable pass`r`n"
$script += "} catch {`r`n"
$script += "  Write-Warning 'Error reading credential files'`r`n"
$script += "}"
$script | Out-File $incscr -Encoding ascii
