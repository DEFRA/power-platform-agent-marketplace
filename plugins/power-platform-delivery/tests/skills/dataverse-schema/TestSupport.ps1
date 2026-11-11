$script:ScriptsFolder = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))) 'skills/dataverse-schema/scripts'

function New-SolutionFixture {
    param([string]$Root)

    $entityFolder = Join-Path $Root 'AbcCases/Entities/abc_Inspection'
    New-Item -ItemType Directory -Path $entityFolder -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $Root 'AbcCases/OptionSets') -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $entityFolder 'Entity.xml') -Value @'
<Entity>
  <Name LocalizedName="Inspection" OriginalName="Inspection">abc_Inspection</Name>
  <EntityInfo>
    <entity Name="abc_inspection">
      <attributes>
        <attribute PhysicalName="abc_Name">
          <Type>nvarchar</Type>
          <Name>abc_name</Name>
          <LogicalName>abc_name</LogicalName>
          <RequiredLevel>required</RequiredLevel>
          <MaxLength>100</MaxLength>
          <Format>text</Format>
          <ValidForCreateApi>1</ValidForCreateApi>
        </attribute>
        <attribute PhysicalName="abc_ScheduledOn">
          <Type>datetime</Type>
          <Name>abc_scheduledon</Name>
          <LogicalName>abc_scheduledon</LogicalName>
          <RequiredLevel>none</RequiredLevel>
          <Format>date</Format>
          <Behavior>2</Behavior>
          <ValidForCreateApi>1</ValidForCreateApi>
        </attribute>
        <attribute PhysicalName="abc_Outcome">
          <Type>picklist</Type>
          <Name>abc_outcome</Name>
          <LogicalName>abc_outcome</LogicalName>
          <RequiredLevel>none</RequiredLevel>
          <ValidForCreateApi>1</ValidForCreateApi>
          <optionset Name="abc_inspection_outcome">
            <options>
              <option value="1"><labels><label languagecode="1033" description="Passed" /></labels></option>
              <option value="2"><labels><label languagecode="1033" description="Failed" /></labels></option>
            </options>
          </optionset>
        </attribute>
        <attribute PhysicalName="abc_Kind">
          <Type>picklist</Type>
          <Name>abc_kind</Name>
          <LogicalName>abc_kind</LogicalName>
          <RequiredLevel>none</RequiredLevel>
          <OptionSetName>abc_inspectionkind</OptionSetName>
          <ValidForCreateApi>1</ValidForCreateApi>
        </attribute>
        <attribute PhysicalName="abc_ApplicantId">
          <Type>lookup</Type>
          <Name>abc_applicantid</Name>
          <LogicalName>abc_applicantid</LogicalName>
          <RequiredLevel>required</RequiredLevel>
          <ValidForCreateApi>1</ValidForCreateApi>
        </attribute>
      </attributes>
    </entity>
  </EntityInfo>
</Entity>
'@

    Set-Content -LiteralPath (Join-Path $Root 'AbcCases/OptionSets/abc_inspectionkind.xml') -Value @'
<optionset Name="abc_inspectionkind">
  <options>
    <option value="10"><labels><label languagecode="1033" description="Routine" /></labels></option>
    <option value="20"><labels><label languagecode="1033" description="Follow-up" /></labels></option>
  </options>
</optionset>
'@
}

function New-ModelFixture {
    param([string]$Root)

    $folder = Join-Path $Root 'Model/Entities'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $folder 'abc_inspection.cs') -Value @'
namespace Abc.Model
{
    [Microsoft.Xrm.Sdk.Client.EntityLogicalNameAttribute("abc_inspection")]
    public partial class abc_Inspection : Microsoft.Xrm.Sdk.Entity
    {
        public static class Fields
        {
            public const string abc_name = "abc_name";
            public const string abc_receivedon = "abc_receivedon";
        }

        [Microsoft.Xrm.Sdk.AttributeLogicalNameAttribute("abc_name")]
        public string abc_Name
        {
            get { return this.GetAttributeValue<string>("abc_name"); }
        }

        [Microsoft.Xrm.Sdk.AttributeLogicalNameAttribute("abc_receivedon")]
        public System.Nullable<System.DateTime> abc_receivedon
        {
            get { return this.GetAttributeValue<System.DateTime?>("abc_receivedon"); }
        }

        [Microsoft.Xrm.Sdk.AttributeLogicalNameAttribute("abc_outcome")]
        public virtual abc_inspection_outcome? abc_Outcome
        {
            get { return null; }
        }
    }
}
'@
}
