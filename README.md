


# XML syntax notes

- Comments cannot contain "==" nor "--"

- Every attributes MUST be double-quoted :

```xml
<UIButton 	name="myButton" 
			width="PARENT_WIDTH" height="42" 
			style="STYLE_SMALL_BUTTON" buttontype="radio" groupid="1" groupmemberid="1"
			update="true" 
			OnSelected="UIObject_Misc_ExecuteServerScript('gui_dm_inventory','SelectEquipement',local:10,local:11)"
			OnUpdate="UIButton_OnUpdate_SetCheckedIfLocalVarEquals(local:11,1)">
</Button>
```