# Extend jQuery with helper functions to quickly enable/disable
# Bootstrap buttons
$.fn.extend
    enable: () ->
        return @removeAttr("disabled")
    disable: () ->
        return @attr("disabled", "disabled")

# When extending a Backbone Model, the second argument
# contains the class-methods and variables that can be
# accessed directly from the 'class' itself
BluetoothState = Backbone.Model.extend({}, {
    Off:            1
    Busy:           2
    Ready:          3
    Connected:      4
})

# We set our initial state as Off
Bluetooth = new BluetoothState({ state: BluetoothState.Busy })

# Model for our Bluetooth devices
Device = Backbone.Model.extend
    defaults:
        name:           "name"
        address:        "address"
        isConnected:    false

# And the respective collection
DeviceCollection = Backbone.Collection.extend
    model: Device

# View for a single bluetooth-device, that handles the
# connect and disconnect functionality
DeviceView = Backbone.View.extend
    template: templates.device

    events: 
        "click .btn-bt-connect":    "connect"
        "click .btn-bt-disconnect": "disconnect"

    initialize: () ->
        @model.on("change", @render, @)

    # In 'subviews' it is customary to return 'this' for 
    # 'render'-method chaining via 'el'
    render: () ->
        @$el.html(_.template(@template, { 
            name:           @model.get("name")
            isConnected:    @model.get("isConnected")
        }))
        return @

    connect: () ->
        onError = () =>
            Bluetooth.set({ state: BluetoothState.Ready })
            @$(".btn-bt-connect").button("reset")

        gotUuids = (device) =>
            onConnectionEstablished = () =>
                onMessageReceived = (msg) =>
                    console.log(msg);

                onConnectionLost = () =>
                    @model.set({ isConnected: false })
                    onError()

                @model.set({ isConnected: true });

                # When a connection has been established, we can start listening
                # to received messages. We could also write to the current connection
                # using 'window.bluetooth.write' method
                window.bluetooth.startConnectionManager(onMessageReceived, onConnectionLost)

            # After getting the UUIDs, we use the first one to try and
            # establish connection with the device at given address
            window.bluetooth.connect(onConnectionEstablished, onError, {
                address:    @model.get("address")
                uuid:       device.uuids[0]
            })

        Bluetooth.set({ state: BluetoothState.Busy })
        @$(".btn-bt-connect").button("loading")

        # We first get the UUIDs of the device we want to connect to
        window.bluetooth.getUuids(gotUuids, onError, @model.get("address"))

    disconnect: () ->
        onDisconnected = () ->
            @model.set({ isConnected: false })
            Bluetooth.set({ state: BluetoothState.Ready })

        Bluetooth.set({ state: BluetoothState.Busy })
        window.bluetooth.disconnect(onDisconnected)

# This view acts as a 'parent' to 'DeviceViews' and appends them
# to the DOM-structure
DeviceListView = Backbone.View.extend
    el: "#list-devices"

    initialize: () ->
        @collection.on("reset add", @render, @)

    render: () ->
        @$el.html("")
        @collection.each (device) =>
            @$el.append(new DeviceView({ model: device }).render().el)

# Gets called after phonegap has finished loading and is ready to be used 
onDeviceReady = () ->
    deviceList = new DeviceListView({ collection: new DeviceCollection })

    # When Bluetooth changes its state (eg. Off, Ready), we
    # adjust the UI elements to match the state
    onBluetoothStateChanged = () ->
        switch Bluetooth.get("state")
            when BluetoothState.Off
                $("#btn-bt-on").enable()
                $("#btn-bt-off").disable()
                $("#btn-bt-discover").disable()
                $(".btn-bt-connect").disable()
                $(".btn-bt-disconnect").disable()
            when BluetoothState.Busy
                $("#btn-bt-on").disable()
                $("#btn-bt-off").disable()
                $("#btn-bt-discover").disable()
                $(".btn-bt-connect").disable()
                $(".btn-bt-disconnect").disable()
            when BluetoothState.Ready
                $("#btn-bt-on").disable()
                $("#btn-bt-off").enable()
                $("#btn-bt-discover").enable()
                $(".btn-bt-connect").enable()
                $(".btn-bt-disconnect").enable()
            when BluetoothState.Connected
                $("#btn-bt-on").disable()
                $("#btn-bt-off").disable()
                $("#btn-bt-discover").disable()
                $(".btn-bt-connect").disable()
                $(".btn-bt-disconnect").enable()

    # Invoked when 'On'-button is pressed
    onToggleOn = () ->
        onBluetoothEnabled = () ->
            Bluetooth.set({ state: BluetoothState.Ready })

        Bluetooth.set({ state: BluetoothState.Busy })
        window.bluetooth.enable(onBluetoothEnabled)

    # Invoked when 'Off'-button is pressed
    onToggleOff = () ->
        onBluetoothDisabled = () ->
            Bluetooth.set({ state: BluetoothState.Off })

        Bluetooth.set({ state: BluetoothState.Busy })
        window.bluetooth.disable(onBluetoothDisabled)

    # Invoked when 'Dicovery'-button is pressed
    onDiscover = () ->
        onDeviceDiscovered = (device) ->
            deviceList.collection.add(new Device(device))

        onDiscoveryFinished = () ->
            Bluetooth.set({ state: BluetoothState.Ready })
            $("#btn-bt-discover").button("reset")

        Bluetooth.set({ state: BluetoothState.Busy })

        # Bootstrap buttons have a special 'loading'-state, where the
        # button is disabled and text is replaced with the one inside
        # 'data-loading-text'-attribute
        $("#btn-bt-discover").button("loading")

        # Clear the current list of devices when discovery is started
        deviceList.collection.reset()

        # Start the discovery for Bluetooth devices
        window.bluetooth.startDiscovery(onDeviceDiscovered, onDiscoveryFinished, onDiscoveryFinished)

    # Set needed event-listeners
    $("#btn-bt-on").on("click", onToggleOn)
    $("#btn-bt-off").on("click", onToggleOff)
    $("#btn-bt-discover").on("click", onDiscover)
    Bluetooth.on("change", onBluetoothStateChanged)

    # Do an initial check of Bluetooth-state
    window.bluetooth.isEnabled (isEnabled) ->
        if isEnabled
            Bluetooth.set({ state: BluetoothState.Ready })
        else
            Bluetooth.set({ state: BluetoothState.Off })

# When 'deviceready'-event happens, we start our app
$(document).on("deviceready", onDeviceReady)
