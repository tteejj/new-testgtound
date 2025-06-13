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

# Global job tracking for cleanup
$script:TuiAsyncJobs = @()

function global:Invoke-TuiAsync {
    <#
    .SYNOPSIS
    Executes a script block asynchronously with proper job management
    
    .PARAMETER ScriptBlock
    The script block to execute asynchronously
    
    .PARAMETER OnComplete
    Handler to call when the job completes successfully
    
    .PARAMETER OnError
    Handler to call if the job encounters an error
    
    .PARAMETER ArgumentList
    Arguments to pass to the script block
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter()]
        [scriptblock]$OnComplete = {},
        
        [Parameter()]
        [scriptblock]$OnError = {},
        
        [Parameter()]
        [array]$ArgumentList = @()
    )
    
    try {
        # Start the job
        $job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
        
        # Track the job for cleanup
        $script:TuiAsyncJobs += $job
        
        # Create a timer to check job status
        $timer = New-Object System.Timers.Timer
        $timer.Interval = 100  # Check every 100ms
        $timer.AutoReset = $true
        
        # Use Register-ObjectEvent to handle the timer tick
        $timerEvent = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            $job = $Event.MessageData.Job
            $onComplete = $Event.MessageData.OnComplete
            $onError = $Event.MessageData.OnError
            $timer = $Event.MessageData.Timer
            
            if ($job.State -eq 'Completed') {
                try {
                    $result = Receive-Job -Job $job -ErrorAction Stop
                    Remove-Job -Job $job -Force
                    
                    # Remove from tracking
                    $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                    
                    # Stop and dispose timer
                    $timer.Stop()
                    $timer.Dispose()
                    Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                    
                    # Call completion handler on UI thread
                    if ($onComplete) {
                        & $onComplete -Data $result
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Warning "Job receive error: $_"
                }
            }
            elseif ($job.State -eq 'Failed') {
                try {
                    $error = $job.ChildJobs[0].JobStateInfo.Reason
                    Remove-Job -Job $job -Force
                    
                    # Remove from tracking
                    $script:TuiAsyncJobs = @($script:TuiAsyncJobs | Where-Object { $_ -ne $job })
                    
                    # Stop and dispose timer
                    $timer.Stop()
                    $timer.Dispose()
                    Unregister-Event -SourceIdentifier $Event.SourceIdentifier
                    
                    # Call error handler
                    if ($onError) {
                        & $onError -Error $error
                        Request-TuiRefresh
                    }
                } catch {
                    Write-Warning "Job error handling failed: $_"
                }
            }
        } -MessageData @{
            Job = $job
            OnComplete = $OnComplete
            OnError = $OnError
            Timer = $timer
        }
        
        # Start the timer
        $timer.Start()
        
        # Return job info
        return @{
            Job = $job
            Timer = $timer
            EventSubscription = $timerEvent
        }
        
    } catch {
        Write-Warning "Failed to start async operation: $_"
        if ($OnError) {
            & $OnError -Error $_
        }
    }
}

function global:Create-TuiState {
    <#
    .SYNOPSIS
    Creates a reactive state management system with deep change detection
    
    .PARAMETER InitialState
    The initial state values
    
    .PARAMETER DeepWatch
    Enable deep property change detection (impacts performance)
    #>
    param(
        [Parameter()]
        [hashtable]$InitialState = @{},
        
        [Parameter()]
        [bool]$DeepWatch = $false
    )
    
    $stateManager = @{
        _data = $InitialState.Clone()
        _subscribers = @{}
        _deepWatch = $DeepWatch
        _changeQueue = @()
        _processing = $false
        
        GetValue = {
            param([string]$Path)
            if (-not $Path) { return $this._data }
            
            $parts = $Path -split '\.'
            $current = $this._data
            
            foreach ($part in $parts) {
                if ($null -eq $current) { return $null }
                $current = $current[$part]
            }
            
            return $current
        }
        
        SetValue = {
            param([string]$Path, $Value)
            
            $parts = $Path -split '\.'
            $current = $this._data
            
            # Navigate to parent
            for ($i = 0; $i -lt $parts.Count - 1; $i++) {
                $part = $parts[$i]
                if (-not $current.ContainsKey($part)) {
                    $current[$part] = @{}
                }
                $current = $current[$part]
            }
            
            # Get old value for comparison
            $lastPart = $parts[-1]
            $oldValue = $current[$lastPart]
            
            # Set new value
            $current[$lastPart] = $Value
            
            # Notify if changed
            if (-not (Compare-TuiValue $oldValue $Value)) {
                & $this.NotifySubscribers -Path $Path -OldValue $oldValue -NewValue $Value
                
                # Also notify parent paths
                $parentPath = ""
                for ($i = 0; $i -lt $parts.Count; $i++) {
                    if ($i -gt 0) { $parentPath += "." }
                    $parentPath += $parts[$i]
                    & $this.NotifySubscribers -Path $parentPath -OldValue $null -NewValue (& $this.GetValue $parentPath)
                }
            }
        }
        
        Update = {
            param([hashtable]$Updates)
            
            # Queue changes to batch notifications
            $this._changeQueue = @()
            
            foreach ($key in $Updates.Keys) {
                $oldValue = $this._data[$key]
                $this._data[$key] = $Updates[$key]
                
                if (-not (Compare-TuiValue $oldValue $Updates[$key])) {
                    $this._changeQueue += @{
                        Path = $key
                        OldValue = $oldValue
                        NewValue = $Updates[$key]
                    }
                }
            }
            
            # Process all notifications
            if ($this._changeQueue.Count -gt 0 -and -not $this._processing) {
                $this._processing = $true
                try {
                    foreach ($change in $this._changeQueue) {
                        & $this.NotifySubscribers @change
                    }
                } finally {
                    $this._processing = $false
                    $this._changeQueue = @()
                }
            }
        }
        
        Subscribe = {
            param(
                [string]$Path,
                [scriptblock]$Handler,
                [string]$SubscriptionId = [Guid]::NewGuid().ToString()
            )
            
            if (-not $this._subscribers.ContainsKey($Path)) {
                $this._subscribers[$Path] = @()
            }
            
            $this._subscribers[$Path] += @{
                Id = $SubscriptionId
                Handler = $Handler
            }
            
            # Call handler with current value
            $currentValue = & $this.GetValue $Path
            try {
                & $Handler -NewValue $currentValue -OldValue $null -Path $Path
            } catch {
                Write-Warning "State subscriber error: $_"
            }
            
            return $SubscriptionId
        }
        
        Unsubscribe = {
            param([string]$SubscriptionId)
            
            foreach ($path in @($this._subscribers.Keys)) {
                $this._subscribers[$path] = @($this._subscribers[$path] | Where-Object { $_.Id -ne $SubscriptionId })
                if ($this._subscribers[$path].Count -eq 0) {
                    $this._subscribers.Remove($path)
                }
            }
        }
        
        NotifySubscribers = {
            param([string]$Path, $OldValue, $NewValue)
            
            # Exact path subscribers
            if ($this._subscribers.ContainsKey($Path)) {
                foreach ($sub in $this._subscribers[$Path]) {
                    try {
                        & $sub.Handler -NewValue $NewValue -OldValue $OldValue -Path $Path
                    } catch {
                        Write-Warning "State notification error: $_"
                    }
                }
            }
            
            # Wildcard subscribers (e.g., "user.*")
            foreach ($subPath in $this._subscribers.Keys) {
                if ($subPath.EndsWith('*')) {
                    $basePath = $subPath.TrimEnd('*').TrimEnd('.')
                    if ($Path.StartsWith($basePath)) {
                        foreach ($sub in $this._subscribers[$subPath]) {
                            try {
                                & $sub.Handler -NewValue $NewValue -OldValue $OldValue -Path $Path
                            } catch {
                                Write-Warning "State wildcard notification error: $_"
                            }
                        }
                    }
                }
            }
        }
        
        Reset = {
            param([hashtable]$NewState = @{})
            $oldData = $this._data
            $this._data = $NewState.Clone()
            
            # Notify all subscribers of reset
            foreach ($path in $this._subscribers.Keys) {
                $oldValue = Get-NestedProperty -Object $oldData -Path $path
                $newValue = & $this.GetValue $path
                
                if (-not (Compare-TuiValue $oldValue $newValue)) {
                    & $this.NotifySubscribers -Path $path -OldValue $oldValue -NewValue $newValue
                }
            }
        }
    }
    
    return $stateManager
}

function Compare-TuiValue {
    <#
    .SYNOPSIS
    Compares two values for equality, handling nulls and complex types
    #>
    param($Value1, $Value2)
    
    if ($null -eq $Value1 -and $null -eq $Value2) { return $true }
    if ($null -eq $Value1 -or $null -eq $Value2) { return $false }
    
    if ($Value1 -is [hashtable] -and $Value2 -is [hashtable]) {
        if ($Value1.Count -ne $Value2.Count) { return $false }
        foreach ($key in $Value1.Keys) {
            if (-not $Value2.ContainsKey($key)) { return $false }
            if (-not (Compare-TuiValue $Value1[$key] $Value2[$key])) { return $false }
        }
        return $true
    }
    
    if ($Value1 -is [array] -and $Value2 -is [array]) {
        if ($Value1.Count -ne $Value2.Count) { return $false }
        for ($i = 0; $i -lt $Value1.Count; $i++) {
            if (-not (Compare-TuiValue $Value1[$i] $Value2[$i])) { return $false }
        }
        return $true
    }
    
    return $Value1 -eq $Value2
}

function global:Stop-AllTuiAsyncJobs {
    <#
    .SYNOPSIS
    Stops and cleans up all tracked async jobs
    #>
    
    foreach ($job in $script:TuiAsyncJobs) {
        try {
            if ($job.State -eq 'Running') {
                Stop-Job -Job $job -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Failed to stop job: $_"
        }
    }
    
    $script:TuiAsyncJobs = @()
    
    # Clean up any orphaned timer events
    Get-EventSubscriber | Where-Object { $_.SourceObject -is [System.Timers.Timer] } | ForEach-Object {
        try {
            Unregister-Event -SourceIdentifier $_.SourceIdentifier -ErrorAction SilentlyContinue
            if ($_.SourceObject) {
                $_.SourceObject.Stop()
                $_.SourceObject.Dispose()
            }
        } catch { }
    }
}

function global:Remove-TuiComponent {
    <#
    .SYNOPSIS
    Properly removes a component and cleans up references to prevent memory leaks
    
    .PARAMETER Component
    The component to remove
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component
    )
    
    try {
        # Remove event handlers if the component has an ID or Name
        $componentId = if ($Component.Id) { $Component.Id } elseif ($Component.Name) { $Component.Name } else { $null }
        
        if ($componentId -and (Get-Command -Name "Remove-ComponentEventHandlers" -ErrorAction SilentlyContinue)) {
            Remove-ComponentEventHandlers -ComponentId $componentId
        }
        
        # Clear focus if this component is focused
        if ($global:TuiState -and $global:TuiState.FocusedComponent -eq $Component) {
            if (Get-Command -Name "Clear-ComponentFocus" -ErrorAction SilentlyContinue) {
                Clear-ComponentFocus
            } else {
                $global:TuiState.FocusedComponent = $null
            }
        }
        
        # Break circular references
        if ($Component.Parent) {
            # Remove from parent's children collection
            if ($Component.Parent._children -and $Component.Name) {
                $Component.Parent._children.Remove($Component.Name)
            }
            if ($Component.Parent.Children) {
                $Component.Parent.Children = @($Component.Parent.Children | Where-Object { $_ -ne $Component })
            }
            $Component.Parent = $null
        }
        
        if ($Component.ParentScreen) {
            # Remove from parent screen's children
            if ($Component.ParentScreen._children -and $Component.Name) {
                $Component.ParentScreen._children.Remove($Component.Name)
            }
            # Remove from focusable names
            if ($Component.ParentScreen._focusableNames) {
                $Component.ParentScreen._focusableNames = @($Component.ParentScreen._focusableNames | Where-Object { $_ -ne $Component.Name })
            }
            $Component.ParentScreen = $null
        }
        
        # Clear children references
        if ($Component.Children) {
            foreach ($child in $Component.Children) {
                if ($child -is [hashtable]) {
                    $child.Parent = $null
                    $child.ParentScreen = $null
                }
            }
            $Component.Children = @()
        }
        
        if ($Component._children) {
            foreach ($childName in @($Component._children.Keys)) {
                $child = $Component._children[$childName]
                if ($child -is [hashtable]) {
                    $child.Parent = $null
                    $child.ParentScreen = $null
                }
            }
            $Component._children.Clear()
        }
        
        # Call component's dispose method if it exists
        if ($Component.Dispose) {
            try {
                & $Component.Dispose -self $Component
            } catch {
                Write-Warning "Component dispose error: $_"
            }
        }
        
        # Clear any async operations or timers
        if ($Component._timers) {
            foreach ($timer in $Component._timers) {
                if ($timer -and $timer.Enabled) {
                    $timer.Stop()
                    $timer.Dispose()
                }
            }
            $Component._timers = @()
        }
        
        # Clear state subscriptions
        if ($Component._stateSubscriptions) {
            foreach ($sub in $Component._stateSubscriptions) {
                if ($sub -and (Get-Command -Name "Unsubscribe-Event" -ErrorAction SilentlyContinue)) {
                    try {
                        Unsubscribe-Event -HandlerId $sub
                    } catch { }
                }
            }
            $Component._stateSubscriptions = @()
        }
        
        # Remove from global component registry if registered
        if ($global:TuiState -and $global:TuiState.Components) {
            $global:TuiState.Components = @($global:TuiState.Components | Where-Object { $_ -ne $Component })
        }
        
        Write-Verbose "Component removed: $componentId"
        
    } catch {
        Write-Warning "Error removing component: $_"
    }
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
    'Apply-Layout',
    'Remove-TuiComponent',
    'Invoke-TuiAsync',
    'Stop-AllTuiAsyncJobs',
    'Create-TuiState',
    'Compare-TuiValue'
)