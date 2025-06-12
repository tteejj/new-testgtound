# TUI Framework Integration Module - FIXED VERSION
# Addresses critical performance issues and architectural conflicts

$script:ComponentRegistry = @{}
$script:LayoutCache = @{}

function global:Initialize-TuiFramework {
    <#
    .SYNOPSIS
    Initializes the complete TUI framework with all subsystems
    #>
    
    # Ensure engine is initialized
    if (-not $global:TuiState) {
        throw "TUI Engine must be initialized before framework"
    }
    
    # Initialize component registry with factories
    $script:ComponentRegistry = @{
        Base = { param($Props) New-TuiComponent @Props }
        Label = { param($Props) New-TuiLabel @Props }
        Button = { param($Props) New-TuiButton @Props }
        TextBox = { param($Props) New-TuiTextBox @Props }
        TextArea = { param($Props) New-TuiTextArea @Props }
        CheckBox = { param($Props) New-TuiCheckBox @Props }
        Dropdown = { param($Props) New-TuiDropdown @Props }
        SearchableDropdown = { param($Props) New-TuiSearchableDropdown @Props }
        Table = { param($Props) New-TuiTable @Props }
        ProgressBar = { param($Props) New-TuiProgressBar @Props }
        DatePicker = { param($Props) New-TuiDatePicker @Props }
        TimePicker = { param($Props) New-TuiTimePicker @Props }
        CalendarPicker = { param($Props) New-TuiCalendarPicker @Props }
        NumberInput = { param($Props) New-TuiNumberInput @Props }
        Slider = { param($Props) New-TuiSlider @Props }
        MultiSelect = { param($Props) New-TuiMultiSelect @Props }
        Chart = { param($Props) New-TuiChart @Props }
        Toast = { param($Props) New-TuiToast @Props }
        Dialog = { param($Props) New-TuiDialog @Props }
        Container = { param($Props) New-TuiContainer @Props }
    }
    
    Write-Verbose "TUI Framework initialized with $($script:ComponentRegistry.Count) component types"
}

function global:Apply-Layout {
    <#
    .SYNOPSIS
    Applies a layout algorithm to position components
    
    .PARAMETER LayoutType
    The type of layout to apply (Stack, Grid, Manual)
    
    .PARAMETER Components
    Array of components to layout
    
    .PARAMETER Options
    Layout-specific options
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$LayoutType,
        
        [Parameter(Mandatory = $true)]
        [array]$Components,
        
        [Parameter()]
        [hashtable]$Options = @{}
    )
    
    switch ($LayoutType) {
        "Stack" {
            Apply-StackLayout -Components $Components -Options $Options
        }
        "Grid" {
            Apply-GridLayout -Components $Components -Options $Options
        }
        "Manual" {
            # Components keep their existing X,Y positions
        }
        default {
            Write-Warning "Unknown layout type: $LayoutType"
        }
    }
}

function Apply-StackLayout {
    param(
        [array]$Components,
        [hashtable]$Options
    )
    
    $orientation = if ($Options.Orientation) { $Options.Orientation } else { "Vertical" }
    $spacing = if ($null -ne $Options.Spacing) { $Options.Spacing } else { 1 }
    $padding = if ($null -ne $Options.Padding) { $Options.Padding } else { 0 }
    $x = if ($null -ne $Options.X) { $Options.X } else { 0 }
    $y = if ($null -ne $Options.Y) { $Options.Y } else { 0 }
    
    $currentX = $x + $padding
    $currentY = $y + $padding
    
    foreach ($component in $Components) {
        if (-not $component.Visible) { continue }
        
        $component.X = $currentX
        $component.Y = $currentY
        
        if ($orientation -eq "Vertical") {
            $currentY += $component.Height + $spacing
        } else {
            $currentX += $component.Width + $spacing
        }
    }
}

function Apply-GridLayout {
    param(
        [array]$Components,
        [hashtable]$Options
    )
    
    $rows = if ($Options.Rows) { $Options.Rows } else { 1 }
    $columns = if ($Options.Columns) { $Options.Columns } else { 1 }
    $spacing = if ($null -ne $Options.Spacing) { $Options.Spacing } else { 1 }
    $padding = if ($null -ne $Options.Padding) { $Options.Padding } else { 0 }
    $x = if ($null -ne $Options.X) { $Options.X } else { 0 }
    $y = if ($null -ne $Options.Y) { $Options.Y } else { 0 }
    $width = if ($Options.Width) { $Options.Width } else { $global:TuiState.BufferWidth }
    $height = if ($Options.Height) { $Options.Height } else { $global:TuiState.BufferHeight }
    
    # Calculate cell dimensions
    $cellWidth = [Math]::Floor(($width - (2 * $padding) - (($columns - 1) * $spacing)) / $columns)
    $cellHeight = [Math]::Floor(($height - (2 * $padding) - (($rows - 1) * $spacing)) / $rows)
    
    $componentIndex = 0
    for ($row = 0; $row -lt $rows; $row++) {
        for ($col = 0; $col -lt $columns; $col++) {
            if ($componentIndex -ge $Components.Count) { break }
            
            $component = $Components[$componentIndex]
            if (-not $component.Visible) { 
                $componentIndex++
                continue 
            }
            
            # Calculate position
            $component.X = $x + $padding + ($col * ($cellWidth + $spacing))
            $component.Y = $y + $padding + ($row * ($cellHeight + $spacing))
            
            # Handle cell spanning
            $colSpan = if ($component.ColSpan) { $component.ColSpan } else { 1 }
            $rowSpan = if ($component.RowSpan) { $component.RowSpan } else { 1 }
            
            # Adjust component size to fit in grid cell(s)
            $component.Width = ($cellWidth * $colSpan) + (($colSpan - 1) * $spacing)
            $component.Height = ($cellHeight * $rowSpan) + (($rowSpan - 1) * $spacing)
            
            $componentIndex++
        }
    }
}

function global:Register-TuiComponentType {
    <#
    .SYNOPSIS
    Registers a component type with the framework
    
    .PARAMETER Type
    The component type name
    
    .PARAMETER Factory
    The factory scriptblock that creates the component
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$Factory
    )
    
    $script:ComponentRegistry[$Type] = $Factory
    Write-Verbose "Registered component type: $Type"
}

function global:Create-TuiComponent {
    <#
    .SYNOPSIS
    Factory method for creating TUI components with type safety
    
    .PARAMETER Type
    The type of component to create
    
    .PARAMETER Props
    Properties to pass to the component constructor
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,
        
        [Parameter()]
        [hashtable]$Props = @{}
    )
    
    if (-not $script:ComponentRegistry.ContainsKey($Type)) {
        throw "Unknown component type: $Type"
    }
    
    $factory = $script:ComponentRegistry[$Type]
    $component = & $factory -Props $Props
    
    # Auto-register with engine if focusable
    if ($component.IsFocusable) {
        Register-Component -Component $component
    }
    
    return $component
}

function global:Create-TuiScreen {
    <#
    .SYNOPSIS
    Creates a screen with automatic component management
    FIXED: No more cloning, uses stateful components with dynamic focus
    
    .PARAMETER Definition
    Screen definition hashtable
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Definition
    )

    $screen = @{
        Name              = if ($Definition.Name) { $Definition.Name } else { "Screen_$(Get-Random)" }
        State             = if ($Definition.State) { $Definition.State } else { @{} }
        _children         = @{} # Internal storage for instantiated components
        _focusableNames   = @() # Names of focusable children, in order
        _focusedIndex     = -1
        Layout            = if ($Definition.Layout) { $Definition.Layout } else { "Manual" }
        LayoutOptions     = if ($Definition.LayoutOptions) { $Definition.LayoutOptions } else { @{} }
        Bindings          = if ($Definition.Bindings) { $Definition.Bindings } else { @{} }

        Init = {
            param($self)
            
            # Wrap a user-provided event handler to inject parent context
            function Wrap-EventHandler {
                param(
                    [scriptblock]$Handler,
                    [hashtable]$ParentScreen,
                    [hashtable]$Component
                )
                
                if (-not $Handler) { return $null }
                
                # Create wrapper that passes both parent screen and component
                $wrapper = {
                    param($EventArgs)
                    
                    # Create event context with all relevant references
                    $context = @{
                        Screen = $wrappedParentScreen
                        Component = $wrappedComponent
                        EventArgs = $EventArgs
                    }
                    
                    # Call original handler with context
                    & $wrappedHandler -Context $context
                }
                
                # Bind variables to the wrapper closure
                $wrapper = $wrapper.GetNewClosure()
                Set-Variable -Name 'wrappedHandler' -Value $Handler -Scope 1
                Set-Variable -Name 'wrappedParentScreen' -Value $ParentScreen -Scope 1
                Set-Variable -Name 'wrappedComponent' -Value $Component -Scope 1
                
                return $wrapper
            }
            
            # Instantiate all child components using the factory
            if ($Definition.Children) {
                foreach ($compDef in $Definition.Children) {
                    try {
                        # Use the factory method instead of string concatenation
                        $component = Create-TuiComponent -Type $compDef.Type -Props $compDef.Props
                        $component.Name = $compDef.Name
                        $component.ParentScreen = $self
                        
                        # Wrap all event handlers with parent context
                        $eventHandlers = @('OnChange', 'OnClick', 'OnFocus', 'OnBlur', 'OnSubmit')
                        foreach ($handlerName in $eventHandlers) {
                            if ($component.$handlerName) {
                                $component.$handlerName = Wrap-EventHandler `
                                    -Handler $component.$handlerName `
                                    -ParentScreen $self `
                                    -Component $component
                            }
                        }
                        
                        $self._children[$component.Name] = $component
                        if ($component.IsFocusable) {
                            $self._focusableNames += $component.Name
                        }
                    }
                    catch {
                        Write-Warning "Failed to create component '$($compDef.Name)' of type '$($compDef.Type)': $_"
                    }
                }
            }

            if ($self._focusableNames.Count -gt 0) {
                $self._focusedIndex = 0
            }
            
            # Call user-defined Init
            if ($Definition.Init) {
                & $Definition.Init -self $self
            }
        }
        
        Render = {
            param($self)
            
            # Call user-defined Render first for backgrounds
            if ($Definition.Render) {
                & $Definition.Render -self $self
            }

            # Apply layout if specified
            if ($self.Layout -ne "Manual" -and $self._children.Count -gt 0) {
                $components = $self._children.Values | Where-Object { $_.Visible }
                Apply-Layout -LayoutType $self.Layout -Components $components -Options $self.LayoutOptions
            }

            # Render each child component WITHOUT CLONING
            foreach ($childName in $self._children.Keys) {
                $child = $self._children[$childName]
                if(-not $child.Visible) { continue }
                
                # Apply data bindings before render
                Apply-DataBindings -Component $child -ScreenState $self.State -Bindings $self.Bindings
                
                # Pass focus state as parameter instead of modifying component
                $isFocused = ($self._focusedIndex -ne -1 -and $childName -eq $self._focusableNames[$self._focusedIndex])
                $isDisabled = if ($child.Disabled) { $child.Disabled } else { $false }
                
                # Call render with state parameters - no more backwards compatibility
                & $child.Render -self $child -IsFocused $isFocused -IsDisabled $isDisabled
            }
        }

        HandleInput = {
            param($self, $Key)
            
            # Handle Tab for focus cycling
            if ($Key.Key -eq [ConsoleKey]::Tab) {
                if ($self._focusableNames.Count -gt 1) {
                    $direction = if ($Key.Modifiers -band [ConsoleModifiers]::Shift) { -1 } else { 1 }
                    $self._focusedIndex = ($self._focusedIndex + $direction + $self._focusableNames.Count) % $self._focusableNames.Count
                    Request-TuiRefresh
                    return $true
                }
            }
            
            # Delegate input to the focused child
            if ($self._focusedIndex -ne -1) {
                $focusedChildName = $self._focusableNames[$self._focusedIndex]
                $focusedChild = $self._children[$focusedChildName]
                
                if (& $focusedChild.HandleInput -self $focusedChild -Key $Key) {
                    # If child handled input and has value binding, update state
                    if ($self.Bindings.ContainsKey($focusedChildName)) {
                        Update-StateFromBinding -Component $focusedChild -ScreenState $self.State -Binding $self.Bindings[$focusedChildName]
                    }
                    return $true
                }
            }

            # Fallback to screen's global handler
            if ($Definition.HandleInput) {
                return & $Definition.HandleInput -self $self -Key $Key
            }
            
            return $false
        }
        
        OnExit = {
            param($self)
            if ($Definition.OnExit) {
                & $Definition.OnExit -self $self
            }
        }
    }
    
    return $screen
}

function Apply-DataBindings {
    <#
    .SYNOPSIS
    Generic data binding system
    #>
    param($Component, $ScreenState, $Bindings)
    
    if (-not $Bindings -or -not $Component.Name) { return }
    
    # Check if this component has bindings
    $binding = $Bindings[$Component.Name]
    if (-not $binding) { return }
    
    # Apply each property binding
    foreach ($prop in $binding.Keys) {
        $statePath = $binding[$prop]
        $value = Get-NestedProperty -Object $ScreenState -Path $statePath
        
        if ($null -ne $value) {
            $Component[$prop] = $value
        }
    }
}

function Update-StateFromBinding {
    <#
    .SYNOPSIS
    Updates state from component value
    #>
    param($Component, $ScreenState, $Binding)
    
    if (-not $Binding) { return }
    
    # Find value properties (common ones)
    $valueProps = @('Value', 'Text', 'SelectedIndex', 'SelectedItem', 'Checked')
    
    foreach ($prop in $valueProps) {
        if ($Component.ContainsKey($prop) -and $Binding.ContainsKey($prop)) {
            $statePath = $Binding[$prop]
            Set-NestedProperty -Object $ScreenState -Path $statePath -Value $Component[$prop]
        }
    }
}

function Get-NestedProperty {
    param($Object, $Path)
    
    $parts = $Path -split '\.'
    $current = $Object
    
    foreach ($part in $parts) {
        if ($null -eq $current) { return $null }
        $current = $current[$part]
    }
    
    return $current
}

function Set-NestedProperty {
    param($Object, $Path, $Value)
    
    $parts = $Path -split '\.'
    $current = $Object
    
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $part = $parts[$i]
        if (-not $current.ContainsKey($part)) {
            $current[$part] = @{}
        }
        $current = $current[$part]
    }
    
    $current[$parts[-1]] = $Value
}

function global:Create-TuiForm {
    <#
    .SYNOPSIS
    Creates a form screen with automatic field management
    FIXED: Uses Stack layout instead of hardcoded coordinates
    
    .PARAMETER Title
    Form title
    
    .PARAMETER Fields
    Array of field definitions
    
    .PARAMETER OnSubmit
    Handler for form submission
    #>
    param(
        [string]$Title = "Form",
        [array]$Fields = @(),
        [scriptblock]$OnSubmit = {},
        [hashtable]$Options = @{}
    )
    
    $formState = @{}
    $formChildren = @()
    $bindings = @{}
    
    # Create field rows
    $fieldIndex = 0
    foreach ($field in $Fields) {
        # Create a container for each field row (label + input)
        $rowContainerName = "FieldRow_$fieldIndex"
        $rowChildren = @()
        
        # Label
        $labelName = "Label_$fieldIndex"
        $rowChildren += @{
            Name = $labelName
            Type = "Label"
            Props = @{
                Text = "$($field.Label):"
                Width = if ($Options.LabelWidth) { $Options.LabelWidth } else { 15 }
                Height = 1
            }
        }
        
        # Field component
        $fieldName = $field.Name
        $fieldType = if ($field.Type) { $field.Type } else { "TextBox" }
        
        $fieldProps = @{
            Width = if ($Options.FieldWidth) { $Options.FieldWidth } else { 35 }
            Height = if ($fieldType -eq "TextArea") { 3 } else { 3 }  # Standard height for inputs
        }
        
        # Add field-specific properties
        foreach ($key in $field.Keys) {
            if ($key -notin @('Label', 'Name', 'Type', 'DefaultValue')) {
                $fieldProps[$key] = $field[$key]
            }
        }
        
        $rowChildren += @{
            Name = $fieldName
            Type = $fieldType
            Props = $fieldProps
        }
        
        # Add the field row container
        $formChildren += @{
            Name = $rowContainerName
            Type = "Container"
            Props = @{
                Height = if ($fieldType -eq "TextArea") { 3 } else { 3 }
                Width = 52  # LabelWidth + FieldWidth + spacing
                Layout = "Stack"
                LayoutOptions = @{ 
                    Orientation = "Horizontal"
                    Spacing = 2
                }
                Children = $rowChildren
            }
        }
        
        # Initialize state and bindings
        $formState[$field.Name] = if ($field.DefaultValue) { $field.DefaultValue } else { "" }
        $bindings[$fieldName] = @{ Value = $field.Name }
        
        $fieldIndex++
    }
    
    # Button container with horizontal stack layout
    $buttonContainerName = "ButtonContainer"
    $formChildren += @{
        Name = $buttonContainerName
        Type = "Container"
        Props = @{
            Height = 3
            Width = 52
            Layout = "Stack"
            LayoutOptions = @{ 
                Orientation = "Horizontal"
                Spacing = 2
                Padding = 1
            }
            Children = @(
                @{
                    Name = "SubmitButton"
                    Type = "Button"
                    Props = @{
                        Width = 12
                        Height = 3
                        Text = "Submit"
                        OnClick = {
                            param($Context)
                            $screen = Get-ScreenContext -Context $Context
                            if ($screen) {
                                $formData = @{}
                                foreach ($field in $Fields) {
                                    $formData[$field.Name] = $screen.State[$field.Name]
                                }
                                & $OnSubmit -FormData $formData
                            }
                        }.GetNewClosure()
                    }
                }
                @{
                    Name = "CancelButton"
                    Type = "Button"
                    Props = @{
                        Width = 12
                        Height = 3
                        Text = "Cancel"
                        OnClick = { Pop-Screen }
                    }
                }
            )
        }
    }
    
    # Calculate form dimensions
    $formWidth = if ($Options.Width) { $Options.Width } else { 60 }
    $totalFieldHeight = $Fields.Count * 4  # 3 for field + 1 for spacing
    $formHeight = if ($Options.Height) { $Options.Height } else { $totalFieldHeight + 10 }  # +10 for padding, buttons, border
    
    # Create the form screen with vertical stack layout
    return Create-TuiScreen -Definition @{
        Name = "$Title`Form"
        State = $formState
        Children = $formChildren
        Bindings = $bindings
        Layout = "Stack"
        LayoutOptions = @{
            X = [Math]::Floor(($global:TuiState.BufferWidth - $formWidth) / 2)
            Y = [Math]::Floor(($global:TuiState.BufferHeight - $formHeight) / 2)
            Orientation = "Vertical"
            Spacing = 1
            Padding = 3
        }
        
        Render = {
            param($self)
            # Draw form border
            $x = $self.LayoutOptions.X
            $y = $self.LayoutOptions.Y
            Write-BufferBox -X $x -Y $y -Width $formWidth -Height $formHeight `
                -Title " $Title " -BorderColor (Get-ThemeColor "Accent")
        }
    }
}

function global:Show-TuiMessageBox {
    <#
    .SYNOPSIS
    Shows a message box dialog
    #>
    param(
        [string]$Title = "Message",
        [string]$Message = "",
        [string[]]$Buttons = @("OK"),
        [scriptblock]$OnButtonClick = {}
    )
    
    $dialog = Create-TuiComponent -Type "Dialog" -Props @{
        Title = $Title
        Message = $Message
        Buttons = $Buttons
        OnButtonClick = $OnButtonClick
    }
    
    # Use the dialog system's Show-TuiDialog if available
    if (Get-Command -Name "Show-TuiDialog" -ErrorAction SilentlyContinue) {
        Show-TuiDialog -DialogComponent $dialog
    } else {
        # Fallback: create a screen wrapper
        $dialogScreen = Create-TuiScreen -Definition @{
            Name = "DialogScreen"
            Children = @(@{ Name = "Dialog"; Type = "Dialog"; Props = $dialog.Props })
        }
        Push-Screen -Screen $dialogScreen
    }
}

function global:Show-TuiNotification {
    <#
    .SYNOPSIS
    Shows a toast notification
    #>
    param(
        [string]$Message,
        [string]$Type = "Info",
        [int]$Duration = 3000
    )
    
    if (Get-Command -Name "Publish-Event" -ErrorAction SilentlyContinue) {
        Publish-Event -EventName "Notification.Show" -Data @{
            Text = $Message
            Type = $Type
            Duration = $Duration
        }
    } else {
        # Fallback to status line
        Write-StatusLine -Text $Message -ForegroundColor (Get-ThemeColor $Type)
    }
}

function global:Create-TuiWizard {
    <#
    .SYNOPSIS
    Creates a multi-step wizard interface
    #>
    param(
        [string]$Title,
        [array]$Steps,
        [scriptblock]$OnComplete
    )
    
    $wizardState = @{
        CurrentStep = 0
        Data = @{}
        StepStates = @{}  # Store state for each step
    }
    
    # Initialize step states
    for ($i = 0; $i -lt $Steps.Count; $i++) {
        $wizardState.StepStates[$i] = @{}
    }
    
    $wizard = Create-TuiScreen -Definition @{
        Name = "$Title`Wizard"
        State = $wizardState
        
        Render = {
            param($self)
            
            # Progress indicator
            $progressY = 2
            $progressText = "Step $($self.State.CurrentStep + 1) of $($Steps.Count)"
            Write-BufferString -X 10 -Y $progressY -Text $progressText
            
            # Progress bar
            $progress = ($self.State.CurrentStep + 1) / $Steps.Count
            $progressBarWidth = 60
            $filledWidth = [Math]::Floor($progressBarWidth * $progress)
            $emptyWidth = $progressBarWidth - $filledWidth
            
            Write-BufferString -X 10 -Y ($progressY + 1) `
                -Text ("█" * $filledWidth + "░" * $emptyWidth) `
                -ForegroundColor (Get-ThemeColor "Success")
            
            # Current step
            $currentStep = $Steps[$self.State.CurrentStep]
            if ($currentStep.Render) {
                & $currentStep.Render -self $self -StepData $self.State.StepStates[$self.State.CurrentStep]
            }
            
            # Navigation buttons
            $navY = 20
            if ($self.State.CurrentStep -gt 0) {
                Write-BufferString -X 10 -Y $navY -Text "[← Previous]" -ForegroundColor (Get-ThemeColor "Primary")
            }
            
            if ($self.State.CurrentStep -lt ($Steps.Count - 1)) {
                Write-BufferString -X 60 -Y $navY -Text "[Next →]" -ForegroundColor (Get-ThemeColor "Primary")
            } else {
                Write-BufferString -X 60 -Y $navY -Text "[Complete ✓]" -ForegroundColor (Get-ThemeColor "Success")
            }
        }
        
        HandleInput = {
            param($self, $Key)
            
            $currentStep = $Steps[$self.State.CurrentStep]
            $currentStepState = $self.State.StepStates[$self.State.CurrentStep]
            
            # Let step handle input first
            if ($currentStep.HandleInput) {
                $result = & $currentStep.HandleInput -self $self -Key $Key -StepData $currentStepState
                if ($result) { return $result }
            }
            
            # Navigation
            switch ($Key.Key) {
                ([ConsoleKey]::LeftArrow) {
                    if ($self.State.CurrentStep -gt 0) {
                        # Save current step data
                        if ($currentStep.SaveData) {
                            & $currentStep.SaveData -StepData $currentStepState -WizardData $self.State.Data
                        }
                        
                        $self.State.CurrentStep--
                        Request-TuiRefresh
                        return $true
                    }
                }
                ([ConsoleKey]::RightArrow) {
                    if ($self.State.CurrentStep -lt ($Steps.Count - 1)) {
                        # Validate current step
                        if ($currentStep.Validate) {
                            $isValid = & $currentStep.Validate -StepData $currentStepState
                            if (-not $isValid) {
                                Show-TuiNotification -Message "Please complete all required fields" -Type "Warning"
                                return $true
                            }
                        }
                        
                        # Save current step data
                        if ($currentStep.SaveData) {
                            & $currentStep.SaveData -StepData $currentStepState -WizardData $self.State.Data
                        }
                        
                        $self.State.CurrentStep++
                        Request-TuiRefresh
                        return $true
                    } else {
                        # Complete wizard
                        if ($currentStep.SaveData) {
                            & $currentStep.SaveData -StepData $currentStepState -WizardData $self.State.Data
                        }
                        
                        if ($OnComplete) {
                            & $OnComplete -WizardData $self.State.Data
                        }
                        Pop-Screen
                        return $true
                    }
                }
            }
            
            return $false
        }
    }
    
    return $wizard
}

function global:Get-ScreenContext {
    <#
    .SYNOPSIS
    Helper to get current screen context from event handler
    #>
    param($Context)
    
    if ($Context -is [hashtable] -and $Context.Screen) {
        return $Context.Screen
    }
    
    # Fallback for old-style handlers
    return $null
}

# Export all functions
Export-ModuleMember -Function @(
    'Initialize-TuiFramework',
    'Register-TuiComponentType',
    'Create-TuiComponent',
    'Create-TuiScreen',
    'Create-TuiForm',
    'Show-TuiMessageBox',
    'Show-TuiNotification',
    'Create-TuiWizard',
    'Get-ScreenContext',
    'Apply-Layout'
)