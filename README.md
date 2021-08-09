# Evolve Framework
A ROBLOX Luau custom framework, object oriented in nature, featuring classes and inheritance.


# Installation

1. Get the latest version of **Evolve** from [Releases](https://github.com/1Humza/evolve-framework/releases)
2. In an existing Roblox Studio instance right click `ServerScriptService` & choose `Insert From File` from the dropdown
    
    <img src="https://user-images.githubusercontent.com/70859111/128649899-18b58449-a42e-405b-a8fb-eb50598cdbbe.png" width="300" height="350">
3. Select the file you just downloaded and press `Open`
    
    <img src="https://user-images.githubusercontent.com/70859111/128650065-3833cd49-adaa-405c-bfe6-5928fc84fa29.png" width="150" height="150">
    
#  Documentation
Below will hopefully be all the documentation needed to utilize the framework. Everything will be kept within `Server Script Service`.

   ![image](https://user-images.githubusercontent.com/70859111/128654461-f2dd32aa-5dcc-4e11-8b98-19de1c021bf8.png)
## Modules

   ![image](https://user-images.githubusercontent.com/70859111/128655363-33d0f7aa-aa55-4c62-9392-e43cec28a034.png)

The Modules are organized with between these 4 sub folders:
- [Classes](#classes)
- [Client](#client)
  - Only accessible via the client-side scripts.
- [Server](#server)
    - Only accessible via the server-side scripts.
- [Shared](#shared)
    - Accessible via both client and server side scripts.

### Classes
Sub folders of this folder are named based on the class that they hold.

![image](https://user-images.githubusercontent.com/70859111/128658321-5231245a-c17a-4f60-afe6-2c0811c579a9.png)

Modules that make up a class must be prefixed with the class name. In the case of the example above, it should be `Template`.
Following the class name is `-` followed by one of the following identifiers:
- `Client`
    - User interface related classes are an example of what you would want suffix with this.
- `Server`
    - Back end mechanics that aren not to be visible to the should use this suffix.
- `Shared`
*These share the same rules at the latter 3 folders under Modules as explained [here](#modules).*

The latter 3 folders are where you delegate access to your modules. Access is organized by the same rules as explained in Classes.
* Client
* Server
* Shared

# Methods

