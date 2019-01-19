###
# The charts displaying data on consultants, asume that those are a member of a group called "Consultants" change the name if needed.
$ConsultantsGroup = Get-ADGroup Consultants

###

$theme = Get-UDTheme Azure # https://docs.universaldashboard.io/themes

#region begin Scheduler
# https://docs.universaldashboard.io/endpoints/scheduled-endpoints
# An UDEndpoint is a scriptblock that runs at a interval defined by UDEndpointSchedule
# Data can be stored in $Cache:VariableName and is available throught the dashboard.
$ScheduleTimer1 = New-UDEndpointSchedule -Every 60 -Second

$Schedule1 = New-UDEndpoint -Schedule $ScheduleTimer1 -Endpoint {

    # Feel free to set a searchbase to narrow down the returned data
    $AllAccounts = Get-ADUser -Properties LockedOut,Title,Department,AccountExpirationDate,Manager,Office
    $ConsultantAccounts = Get-ADGroupMember $ConsultantsGroup | Get-ADUser -Properties LockedOut,Title,Department,AccountExpirationDate,Manager,Office


#region begin AllUsers
     
    $Cache:AllUsers = $AllAccounts | 
        Select-Object LockedOut,Office,SamAccountName,Name,Department,Title,Manager,@{Name="ExpirationDate";Expression={
                            if($_.AccountExpirationDate -eq $null) 
                                { return "Never"}
                            else
                                {(Get-Date ($_.AccountExpirationDate)).tostring("yyyy-MM-dd HH-mm-ss")}
                            }},@{Name="State";Expression={
                                If($_.Enabled){
                                    If($_.AccountExpirationDate -lt (get-date) -and $_.AccountExpirationDate -ne $null){
                                        Return "Expired"
                                    }
                                    
                                    Return "Enabled"
                                }
                                Else
                                {
                                    Return "Disabled"
                                }
                            }},@{Name="Type";Expression={
                                If ($($ConsultantAccounts | Select-Object -ExpandProperty SamAccountName) -contains $_.SamAccountname) 
                                {
                                    Return "Consultant"
                                } 
                                Else 
                                {
                                    Return "Employee"
                                }
                            }},@{Name="Details";Expression={
                                New-UDButton -Text "Show Details" -OnClick (
                                    New-UDEndpoint -Endpoint {
                                        $EmployeeAD = Get-ADUser $($ArgumentList[0]) -Properties Title,Department,AccountExpirationDate,LockedOut
                                        
                                        $TableData =  @(
                                            [PSCustomObject]@{Name = "Username";  Value = $($EmployeeAD.SamAccountName); Sort = "1"}
                                            [PSCustomObject]@{Name = "Name";  Value = $($EmployeeAD.Name); Sort = "2"}
                                            [PSCustomObject]@{Name = "Title";  Value = $($EmployeeAD.Title); Sort = "3"}
                                            [PSCustomObject]@{Name = "Department";  Value = $($EmployeeAD.Department); Sort = "4"}
                                            [PSCustomObject]@{Name = "locked?";  Value = $(if ($EmployeeAD.LockedOut -eq $null) {"Nope"} else {"Yep"}); Sort = "5"}
                                            [PSCustomObject]@{Name = "Account Expiration Date";  Value = $(if($EmployeeAD.AccountExpirationDate -eq $null) {"Never"} else {(Get-Date ($EmployeeAD.AccountExpirationDate)).tostring("yyyy-MM-dd HH-mm-ss")}); Sort = "6"}

                                        ).GetEnumerator()


                                        Show-UDModal -Header {
                                            New-UDHeading -Size 4 -Text "Here's what we have on $($EmployeeAD.Name)"
                                        } -Content { 
                                            New-UDCard -Title "Account Details" -Content {
                                                New-UDTable -Headers @("Attribute", "Value") -Endpoint {
                                                    $TableData | Sort-Object Sort | Out-UDTableData -Property @("Name", "Value")
                                                }
                                            }
                                        }
                                    } -ArgumentList $($_.ObjectGUID) 
                                )
    
                            }}


#endregion   

#region begin ByDepartment

    $Departments = $AllAccounts | Select-Object -expandProperty Department -Unique | Sort 
    $ByDepartment = $null
    $ByDepartment = New-Object System.Collections.ArrayList
        
    Foreach ($Department in $Departments){
        
    $DepCount = @($Consultants | Where-Object -Property Department -eq $Department).count

        $Counter = [PSCustomObject]@{
                
        'Employees' = $($DepCount);
        'Department' = $Department;
        }
        
        
        $ByDepartment.add($Counter)
    }

    $Cache:ByDepartment = $ByDepartment

#endregion

#region begin ByLocation

    $Offices = $AllAccounts | Select-Object -ExpandProperty Office -Unique | Sort-Object
    $ByOffice = $null
    $ByOffice = New-Object System.Collections.ArrayList
        
    Foreach ($Office in $Offices){
        
    $ConsultantsOfficeCount = @($Consultants | Where-Object -Property Office -eq $Office).count

        $Counter = [PSCustomObject]@{
                
        'Employees' = $($ConsultantsOfficeCount);
        'Office' = $Office;
        }
        
        
        $ByOffice.add($Counter)
    }

    $Cache:OfficeConsultants = $ByOffice


#endregion

#region begin AllConsultants
    $Cache:AllConsultants = $Cache:AllUsers | Where-Object -Property Type -like "Consultant*"
#endregion
#region begin ConsultantsByDepartment

$Departments = $AllAccounts | Select-Object -expandProperty Department -Unique | Sort 
$ByDepartment = $null
$ByDepartment = New-Object System.Collections.ArrayList

Foreach ($Department in $Departments){

$DepCount = @($Consultants | Where-Object -Property Department -eq $Department).count

$Counter = [PSCustomObject]@{
        
'Employees' = $($DepCount);
'Department' = $Department;
}


$ByDepartment.add($Counter)
}

$Cache:ByDepartment = $ByDepartment

#endregion

#region begin ConsultantsByLocation

$Offices = $AllAccounts | Select-Object -ExpandProperty Office -Unique | Sort-Object
$ByOffice = $null
$ByOffice = New-Object System.Collections.ArrayList

Foreach ($Office in $Offices){

$ConsultantsOfficeCount = @($Consultants | Where-Object -Property Office -eq $Office).count

$Counter = [PSCustomObject]@{
        
'Employees' = $($ConsultantsOfficeCount);
'Office' = $Office;
}


$ByOffice.add($Counter)
}

$Cache:OfficeConsultants = $ByOffice


#endregion

#region begin DeclineConsultants
#calculates the decline of "Consultants" accounts over the next 12 months
    $Months = $null
    $Months = New-Object System.Collections.ArrayList
    for ($i = 0; $i -le 12; $i++) { 
        $Dayofthemonth = ((get-date -day 2).addmonths($i).Tostring("yyyy-MM-dd"))
            
        $Months.add($Dayofthemonth)  | Out-Null
    } 

    $ConsultantsPerMonth = $null
    $ConsultantsPerMonth = New-Object System.Collections.ArrayList

    Foreach ($Month in $Months){
        $Data = $Consultants | Where-Object -Property AccountExpirationDate -ge $(Get-date $Month)

        $MonthData = [PSCustomObject]@{
            'Date' = $($Month);
            'Consultants' = @($Data).Count;
            }
        $ConsultantsPerMonth.add($MonthData) | out-null
    }

}

#endregion

# usually i split up my pages in seperate files makes it easier to not f*ck something up.
# simply copy the entire New-UDpage into a PS1 file, place it in a folder and use something like the commented code below.

#$Pages = @()
#
#Get-ChildItem (Join-Path $PSScriptRoot "pages")  | ForEach-Object {
#    $Pages += . $_.FullName
#}
#
#$Dashboard = New-UDDashboard -Title "AD Dashboard" -Theme $Theme -Page $Pages

$EmployeePage = New-UDPage -Name "Employee Page" -Content {
    New-UDCard -Title "Test"

}

$Dashboard = New-UDDashboard -Title "AD Dashboard" -Theme $Theme -Page @(
    $EmployeePage

)

#when making updates, the previous Dashboard has to be stopped before a new can be started on the same port
Get-UDDashboard | Stop-UDDashboard 
Start-UDDashboard -Dashboard $Dashboard -Endpoint @($Schedule1) -Name "AD Dashboard" -Port 101010
