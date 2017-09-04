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

$Credentials = Get-Credential -Message 'Enter the user name and password for the credentials to be encrypted'
if (!$Credentials) {
    Write-Warning "No credentials entered, script exiting"
    return
}

$aesfile  = $FolderBrowser.SelectedPath + '\' + $Credentials.UserName + '.key'
$credfile = $FolderBrowser.SelectedPath + '\' + $Credentials.UserName + '.txt'
$incscr   = $FolderBrowser.SelectedPath + '\' + $Credentials.UserName + '.ps1'

# Check that we can write files to the selected folder
Try { [io.file]::OpenWrite($aesfile).close() }
Catch { Write-Warning "Unable to write to $aesfile, check directory and user file system permissions, exiting" }

# Generate new secure AES-256 key and write to disk
$aeskey = New-Object Byte[] 32      # 32 bytes x 8 bit = 256-bit AES
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($aeskey)
$aeskey | Out-File $aesfile

# Encrypt credentials using key and write encrypted version to disk
ConvertFrom-SecureString -SecureString $Credentials.Password | ConvertTo-SecureString | ConvertFrom-SecureString -Key $aeskey | Out-File $credfile

# At this point both the encrypted credential password and the AES-256 key used to encrypt it have been written to disk
# //TODO - write out script to be included to establish this credential object automatically in a calling script.