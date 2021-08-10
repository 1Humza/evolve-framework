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
## Folders

   ![image](https://user-images.githubusercontent.com/70859111/128655363-33d0f7aa-aa55-4c62-9392-e43cec28a034.png)

The Modules are organized with between these 4 sub folders:
- Classes
- Client
  - Only accessible via the client-side scripts.
- Server
    - Only accessible via the server-side scripts.
- Shared
    - Accessible via both client and server side scripts.

### Classes
Sub folders of this folder are named based on the class that they hold.

![image](https://user-images.githubusercontent.com/70859111/128658321-5231245a-c17a-4f60-afe6-2c0811c579a9.png)

Modules that define a class must be prefixed with the class name. In the case of the example above, it's `Template`.
Following the class name is a dash "`-`" proceeded by one of the following identifiers:
- `Client`
    - User interface related classes are an example of what you would want suffix with this.
- `Server`
    - Back end mechanics that are not to be visible to the client should use this suffix.
- `Shared`\
\
*NOTE: Indentifiers share the same rules as the latter 3 module folders explained [here](#modules).*

## Modules

### Custom Objects
This module creates Custom Objects defined by Classes you create.

#### Methods

```css
new( instance Object, string Class, ... )
```
Creates new `Custom Object` based on `new` constructor defined in the class specified by the second argument. Any more arguments will be passed to the user defined `new` constructor.\
```Returns instance, ...``` alongside any additional variables returned from class defined `new`.\
<br />
```css
Wrap( instance Object, string Class )
```
Wraps passed Object into `Custom Object`. Allows you to transform existing instances into `Custom Objects` to retain properties and explorer hierarchy.\
```Returns customobject```\
<br />
```css
Clone( customobject CustomObject )
```
```Returns customobject```
<br />
<br />
```css
AddSearchBank( customobject CustomObject )
```
```Returns nil```
<br />
<br />
```css
GetObject( customobject CustomObject )
```
Returns base instance that the `Custom Object` wrapper is applied to.\
```Returns instance```\
<br />
```css
GetUUID( customobject CustomObject )
```
Returns unique ID assigned to all `Custom Objects`.\
```Returns integer```\
<br />
