## RACT CRM - Dynamics 365

### What is this repository for? ###

This repository contains the Dynamics 365 Solution for RACT CRM Customisations

### How do I get set up? ###

#### Summary of set up
Running any kind of <code>build</code> from the command line (repository root) will automatically install dependencies on the developers machine, primarily the required version of .Net Core, and the Power Apps CLI (PAC)

#### Configuration
Default configuration settings are held in <code>settings.json</code> in the **setup** folder. These are configured to allow development against the [RACT Dev 1](https://org88bea879.crm6.dynamics.com) Dynamics 365 environment

### Deployment instructions
The following build targets are available from the root folder, by running <code>**build _target_**</code>.

By default, running <code>build</code> with no target will perform a **clean** and **generate** automatically

**Please note**, _default environment_ refers to **RACT Dev 1**


* <code>clean</code> - clean the build folder
* <code>generate</code> - pack the solution files into a Dynamics 365 _unmamaged_ solution archive (zip file), ready for deployment
* <code>apply</code> - perform a **generate**, and then deploy the unmanaged solution to the default environment
* <code>capture</code> - export the solution from the default environment, and then un-pack into the repository source folder, allowing for update/review of changes from develop
* <code>package-managed</code> - export the solution from the default environment as a **managed** solution. This will be placed into the build folder, and will be appended with **-managed**
* <code>apply-managed</code> - deploy the **managed** solution to the default environment. Must be performed _after_ **package-managed**, to ensure the managed solution is available

The **default environment** can be _overridden_ in any of the above targets, by supplying the **-hostname** parameter, i.e. <code>build apply -hostname org2720234e.crm6.dynamics.com</code> would deploy the unmanaged solution to **RACT Dev 2**