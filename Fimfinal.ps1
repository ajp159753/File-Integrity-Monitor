Write-Host ""
Write-Host ""
Write-Host ""

# Prompt for the folder to monitor
$custompath = Read-Host -Prompt "Specify the folder path to monitor"

if (Test-Path $custompath) {
    # Define the name of the .txt file
    $filename = "baseline.txt"
    
    # Combine the path and filename to get the full path
    $fullPath = Join-Path $custompath $filename
    
    # Check if baseline.txt already exists, and create it if not
    if (-Not (Test-Path $fullPath)) {
        "This is a test file created in the specified folder." | Out-File -FilePath $fullPath
        Write-Host "The baseline.txt file has been created at: $fullPath"
    }
} else {
    Write-Host "The specified path does not exist. Please check the path and try again."
    exit
}

Write-Host ""
Write-Host "What do you want to do?"
Write-Host ""
Write-Host "       A) Collect New Baseline"
Write-Host "       B) Begin monitoring files with saved Baseline"
Write-Host ""

$response = Read-Host -Prompt "Please enter 'A' or 'B'"

# Function to calculate file hash
Function calculate_file_hash($filepath) {
    $filehash = Get-FileHash -Path $filepath -Algorithm SHA256
    return $filehash
}

# Function to erase baseline if it exists
Function erase_baseline_if_exists() {
    $baselineExists = Test-Path -Path $fullPath
    if ($baselineExists) {
        # Delete the baseline file if it exists
        Remove-Item -Path $fullPath
        Write-Host "Existing baseline.txt has been deleted."
    }
}

# New baseline creation logic (Option A)
if ($response -eq "A".ToUpper()) {
    # Delete baseline if it exists
    erase_baseline_if_exists

    Write-Host "Collecting new baseline..."

    # 1. Collect all target files from the folder to monitor, excluding baseline.txt
    $files = Get-ChildItem -Path $custompath -File | Where-Object { $_.Name -ne "baseline.txt" }

    # 2. For each file, calculate the hash and store it in baseline.txt
    foreach ($f in $files) {
        $hash = calculate_file_hash $f.FullName
        "$($f.FullName)|$($hash.Hash)" | Out-File -FilePath $fullPath -Append
    }

    Write-Host "New baseline.txt created with file hashes."

    # After creating the new baseline, automatically start monitoring mode (Option B)
    $response = "B"  # Set response to B to start monitoring
}

# Monitoring logic (Option B)
if ($response -eq "B".ToUpper()) {
    Write-Host "Monitoring files based on the existing baseline..."

    # Load file hashes from the baseline.txt and store them in a dictionary
    $filepathsandhashes = Get-Content -Path $fullPath
    $filehashdictionary = @{}
    
    foreach ($f in $filepathsandhashes) {
        $split = $f.Split("|")
        $filehashdictionary[$split[0]] = $split[1]
    }

    $changesDetected = $false  # Flag to track if any changes occurred
    $lastChangeTime = Get-Date  # Track the time of the last detected change

    while ($true) {
        Start-Sleep -Seconds 1

        # 1. Get all the files in the monitored folder, excluding baseline.txt
        $files = Get-ChildItem -Path $custompath -File | Where-Object { $_.Name -ne "baseline.txt" }

        foreach ($f in $files) {
            # Calculate the hash of each file
            $hash = calculate_file_hash $f.FullName

            # Check if the file is new (doesn't exist in baseline)
            if ($filehashdictionary[$f.FullName] -eq $null) {
                Write-Host "$($f.FullName) has been CREATED!" -ForegroundColor Red
                $changesDetected = $true  # Mark that a change has occurred
            }
            else {
                # If the file exists in the baseline, compare its hash
                if ($filehashdictionary[$f.FullName] -eq $hash.Hash) {
                    # File hasn't been altered, no change
                }
                else {
                    Write-Host "$($f.FullName) has CHANGED" -ForegroundColor Red
                    $changesDetected = $true  # Mark that a change has occurred
                }
            }
        }

        # 2. Check for files that were deleted from the baseline
        foreach ($key in $filehashdictionary.Keys) {
            $baselinefilestillexists = Test-Path -Path $key
            if (-Not $baselinefilestillexists) {
                Write-Host "$($key) has been DELETED (or moved)" -ForegroundColor Red
                $changesDetected = $true  # Mark that a change has occurred
            }
        }

        # If no changes have been detected for 5 seconds, show the "Everything is okay" message
        if ($changesDetected) {
            $lastChangeTime = Get-Date  # Reset the time when a change occurs
            $changesDetected = $false  # Reset the flag
        }
        else {
            # If it's been 5 seconds since the last change, display the message
            $timeSinceLastChange = (Get-Date) - $lastChangeTime
            if ($timeSinceLastChange.TotalSeconds -ge 5) {
                Write-Host "Everything is okay. No changes detected for the last 5 seconds." -ForegroundColor Green
                $lastChangeTime = Get-Date  # Reset the timer
            }
        }
    }

} else {
    Write-Host "Invalid input. Please enter 'A' or 'B'."
}