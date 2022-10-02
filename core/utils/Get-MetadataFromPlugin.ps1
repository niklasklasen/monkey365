# Monkey365 - the PowerShell Cloud Security Tool for Azure and Microsoft 365 (copyright 2022) by Juan Garrido
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

Function Get-MetadataFromPlugin{
    <#
        .SYNOPSIS
        Get metadata from installed plugins
        .DESCRIPTION
        Get metadata from installed plugins
        .INPUTS

        .OUTPUTS

        .EXAMPLE

        .NOTES
	        Author		: Juan Garrido
            Twitter		: @tr1ana
            File Name	: Get-MetadataFromPlugins
            Version     : 1.0

        .LINK
            https://github.com/silverhack/monkey365
    #>
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    Param()
    Begin{
        $monkey_plugins = @()
        $p_path = ("{0}/plugins" -f $ScriptPath)
        $params = @{
            Path = $p_path;
            Recurse = $true;
            File = $true;
            Include = "*.ps1";
            ErrorAction = 'Ignore';
        }
        $all_plugins = Get-ChildItem @params
        $all_ast_plugins = Get-AstFunction $all_plugins
    }
    Process{
        if($null -ne $all_ast_plugins){
            #Get all supported services based on Azure plugins
            foreach($ast_plugin in $all_ast_plugins){
                #Get internal Var
                try{
                    $monkey_var = $ast_plugin.Body.BeginBlock.Statements | Where-Object {($null -ne $_.Psobject.Properties.Item('Left')) -and $_.Left.VariablePath.UserPath -eq 'monkey_metadata'}
                    if($monkey_var){
                        $implemented_interfaces = $monkey_var.Right.Expression.StaticType.ImplementedInterfaces | ForEach-Object { $_.FullName }
                    }
                    if($implemented_interfaces -and "System.Collections.IDictionary" -in $implemented_interfaces -and $monkey_var.Operator -eq "Equals"){
                        $new_dict = [System.Collections.Generic.Dictionary[[string],[object]]]::new()
                        foreach ($entry in $monkey_var.Right.Expression.KeyValuePairs) {
                            if($entry.Item2.Extent.Text.StartsWith('@')){
                                #Convert literal string into an array of elements
                                $new_array = $entry.Item2.Extent.Text.Replace('@(','').Replace(')','').Replace('"','').Split(',')
                                $new_dict.Add($entry.Item1.Value,[array]$new_array)
                            }
                            else{
                                $new_dict.Add($entry.Item1.Value,$entry.Item2.Extent.Text.Trim('"').ToString())
                            }
                        }
                        #Add file properties
                        $new_dict.Add('File',(Get-ChildItem $ast_plugin.Extent.File))
                        #Create PsObject
                        $obj = New-Object -TypeName PSCustomObject -Property $new_dict
                        #Add to array
                        $monkey_plugins+=$obj
                    }
                }
                catch{
                    $msg = @{
                        MessageData = $_;
                        callStack = (Get-PSCallStack | Select-Object -First 1);
                        logLevel = 'debug';
                        InformationAction = $script:InformationAction;
                        Tags = @('UnabletoGetPlugin');
                    }
                    Write-Debug @msg
                }
            }
        }
    }
    End{
        return $monkey_plugins
    }
}