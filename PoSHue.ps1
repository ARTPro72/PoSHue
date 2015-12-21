Class HueBridge {
    ##############
    # PROPERTIES #
    ##############

    [ipaddress] $BridgeIP
    [string] $APIKey

    ###############
    # CONSTRUCTOR #
    ###############

    # Constructor to return an API Key
    HueBridge([ipaddress] $Bridge) {
        $this.BridgeIP = $Bridge
    }

    HueBridge([ipaddress] $Bridge, [string] $APIKey) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $APIKey
    }

    ###########
    # METHODS #
    ###########
    [string] GetNewAPIKey() {
        $Result = Invoke-RestMethod -Method Post -Uri "http://$($this.BridgeIP)/api" -Body '{"devicetype":"PoSHue#PowerShell Hue"}'
        
        If ($Result[0].error) {
            Return $Result[0].error.description
        }
        ElseIf ($Result[0].success) {
            # Assign the API Key and return it.
            $this.APIKey = $Result[0].success.username
            Return $Result[0].success.username
        }
        Else {
            Return "There was an error.`r`n$Result"
        }
    }

    [array] GetLightNames() {
        $Result = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        $Lights = $Result.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        Return $Lights.Value.Name

        # The below is not necessary.
        # PoSH extracts the values from the array when an index isn't specified, it seems.
        # Something new every day.
        # Return $Lights | Select-Object @{Name="Hue Light Names"; Expression = {$_.Value.Name}}

    }

}

Class HueLight {

    ##############
    # PROPERTIES #
    ##############

    [string] $Light
    [ipaddress] $BridgeIP
    [string] $APIKey
    [string] $JSON
    [bool] $On
    [ValidateRange(1,254)][int] $Brightness
    [ValidateRange(0,65535)][int] $Hue
    [ValidateRange(1,254)][int] $Saturation
    [ValidateRange(153,500)][int] $ColourTemperature
    
    ###############
    # CONSTRUCTOR #
    ###############

    HueLight([string] $Name, [ipaddress] $Bridge, [string] $API) {
        $this.BridgeIP = $Bridge
        $this.APIKey = $API
        $this.Light = $this.GetHueLight($Name)
        $this.GetStatus()
    }


    ###########
    # METHODS #
    ###########

    hidden [int] GetHueLight([string] $Name) {
        # Change the named light in to the integer used by the bridge. We use this throughout.
        $HueData = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights"
        $Lights = $HueData.PSObject.Members | Where-Object {$_.MemberType -eq "NoteProperty"}
        $this.Light = $Lights | Where-Object {$_.Value.Name -match $Name}  | Select Name -ExpandProperty Name
        Return $this.Light
    }

    hidden [void] GetStatus() {
        # Get the current values of the State, Hue, Saturation, Brightness and Colour Temperatures
        $Status = Invoke-RestMethod -Method Get -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)"
        $this.On = $Status.state.on
        $this.Brightness = $Status.state.bri
        $this.Hue = $Status.state.hue
        $this.Saturation = $Status.state.sat
        $this.ColourTemperature = $Status.state.ct
    }

    [void] SwitchHueLight() {
        # A simple toggle. If on, turn off. If off, turn on.
        
        Switch ($this.On) {
            $false  {$this.On = $true}
            $true {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

    [void] SwitchHueLight([string] $State) { # An overload for SwitchHueLight
    # Set the state of the light. Always does what you give it, irrespective of the current setting.
        Switch ($State) {
            On  {$this.On = $true}
            Off {$this.On = $false}
        }

        $Settings = @{}
        $Settings.Add("on", $this.On)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

    # Importance of colour settings: XY > CT > HS
    # I don't have an XY method as it seems illogical.
    [void] SetHueLight([int] $Brightness, [int] $ColourTemperature) {
        $this.Brightness = $Brightness
        $this.ColourTemperature = $ColourTemperature

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("ct", $this.ColourTemperature)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

    [void] SetHueLight([int] $Brightness, [int] $Hue, [int] $Saturation) {
        # Allows imposing the ValidateRange limits so it seems advisable to do this
        $this.Brightness = $Brightness
        $this.Hue = $Hue
        $this.Saturation = $Saturation

        # Feels a bit verbose to be updating our object data then re-constructing it for use... what to do...what to do...

        $Settings = @{}
        $Settings.Add("bri", $this.Brightness)
        $Settings.Add("hue", $this.Hue)
        $Settings.Add("sat", $this.Saturation)

        $Result = Invoke-RestMethod -Method Put -Uri "http://$($this.BridgeIP)/api/$($this.APIKey)/lights/$($this.Light)/state" -Body (ConvertTo-Json $Settings)
    }

}

##############
# PROCESSING #
##############

# The name of the light
$LightName = "Hue go 1"

# The Bridge IP address
$Endpoint = "192.168.1.12"

# The username created on the bridge
$UserID = "38cbd1cbcac542f9c26ad393739b7"

# Instantiate a Hue Light Object using one of the overloads
# Use this constructor to get a reference to an actual light.
#$Go = [HueLight]::New($LightName, $Endpoint, $UserID)
# No username/API Key/User ID? Use this overload to get a valid username you can use in the other constructor
$Bridge = [HueBridge]::New($Endpoint, $UserID)

#$Bridge.SetAPIKey('4f651f866843eb2e398ac884aac0f18')
$Bridge.GetLightNames()
# Do stuff with the light!

# Toggle it on or off
#$Go.SwitchHueLight()
#$Go.SwitchHueLight("On")
#$Go.SwitchHueLight("Off")

# Set the Brightness, keep the existing hue and saturation
#$Go.SetHueLight(100, $Go.Hue, $Go.Saturation)

# Set the Brightness to 50, keep the existing colour temp
#$Go.SetHueLight(50, $Go.ColourTemperature)

# Set the Brightness to 100, set colour temp to 370
#$Go.SetHueLight(100, 370)

# Just see what the object properties are.
#$Go