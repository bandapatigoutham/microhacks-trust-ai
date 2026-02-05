# Challenge 0: Environment Setup

If you’re running this workshop on your own, you'll need to deploy the workshop resources to your Azure subscription. Follow the instructions to deploy the workshop resources.

## Overview
We will set up the initial environment for you to build on top of during your Microhack. This comprehensive setup includes configuring essential Azure services and ensuring access to all necessary resources. Participants will familiarize themselves with the architecture, gaining insights into how various components interact to create a cohesive solution. With the foundational environment in place, the focus will shift seamlessly to the first Microhack Challenge endeavor.  
<br>
<br>
![Alt text](/media/architecture_ragchat.png "RAGCHAT Architecture")
<br>
<br>

## Prerequisites for Local Environments (LINUX, Windows or MAC)

1. A computer running Windows 11, macOS, or Linux.  Running on your local PC.
1. An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/).
1. Install the [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli).
1. [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
1. Install [Powershell 7 (supported on Windows, macOS, and Linux)](https://learn.microsoft.com/powershell/scripting/install/installing-powershell).
1. Install [Python 3.13](https://www.python.org/downloads/).
1. Install the Git CLI. You can download it from the [Git website](https://git-scm.com/downloads).
1. Install VS Code on your local PC if not using Codespaces.
<br>

## Support Software
* Azure Developer CLI: Download azd
* Ensure the correct OS is selected
* Powershell 7+ with AZ module (Windows only): Powershell, AZ Module
* Git: Download Git
* Python 3.13: Download Python
<br>

## Prerequisites for CodeSpaces
1. An Azure subscription. If you don't have an Azure subscription, create a [free account](https://azure.microsoft.com/free/).
1. Validate [Python 3.13](https://www.python.org/downloads/) is setup in your environment or lower
<br>

## Recommended Regions
* Sweden Central (swedencentral)
* France Central (francecentral)
* US North Central (northcentralus)
* East US 2 (eastus2)
* Switzerland West (switzerlandwest)

- **Optimal Region** for availability should be Sweden Central (Optimal due to Azure OpenAI availability)
- **Alternative Region** for availability should be France Central for Azure OpenAI availability.
<br>

## Setup your Development Environment on your Local PC

1. Start the Microhack on Local Environment.

    a. Open a terminal window for local deployments and confirm prerequisites are complete
        
    * <u>**Fork**</u> the [Microhack Trustworthy AI](https://github.com/microsoft/microhacks-trust-ai) repo into your Github account.  This is a requirement to FORK the repo into your account for CH3 due to Github Actions.
        
    * Clone the <u>**FORKED REPO**</u> in your Github account to your local environment by running the following command:

        * ```git clone https://github.com/<Github username>/microhacks-trust-ai```

    * At the terminal window confirm the home directory ```/microhacks-trust-ai```

1. Make a new Python virtual environment and activate it.  

    ```bash
    python -m venv .evalenv
    ```
1. Activate Python Virtual Environment

    Mac OS X or Linux ```source .evalenv/bin/activate```

    Windows CMD ```.evalenv\Scripts\activate.bat```

    Powershell ```.evalenv\Scripts\Activate.ps1```

1. Install UV to expediate the pip installation

    ```bash
    pip install uv
    ```

1. PIP install the requirements into your virtual environment
    
    ```bash
    uv pip install -r ./scripts/requirements.txt
    ```

1. Change permissions of shell script to deploy Container image
    ```bash
    chmod +x ./scripts/02_deploy_container_apps.sh
    ```

<br>

## Setup your Development Environment on Codespaces

For Codespaces, go into your web browser and login to github.

1. <u>**Fork**</u> the [Microhack Trustworthy AI](https://github.com/microsoft/microhacks-trust-ai) repo into your Github account. This is requirement to FORK the repo into your account for CH3 due to Github Actions.
        
1.  `Click on Code` (Green) button and click on `+` button (Create a codepspaces on main).  This will take a 10 minutes to provision a Codespaces instance.  For Codpespaces only, it will setup your virtual environment and grant write permissions to necessary files.

1. At the terminal window confirm the home directory ```/microhacks-trust-ai```

1. Activate Python Virtual Environment (LINUX)

    ```bash
    source .evalenv/bin/activate
    ```
<br>

## Deploy the Azure Resources

1. Login to your Azure Developer Account in the terminal window

    ```bash
    azd auth login
    ```

1. Login to your Azure Account in the terminal window

    ```bash
    az login
    ```

1. Create a new azd environment

    ```bash
    azd env new
    ```

    Enter a name that will be used for the resource group.  This will create a new `.azure` folder and set it as the active environment for any calls to azd going forward.

1. Run the bicep scripts with the following command:

    ```bash
    azd up
    ```

    This will provision Azure resources and deploy this sample to those resources, including building the search index based on the files found in the `./data` folder.  

1. Open URL for RAGCHAT application printed in the terminal console similar to the below picture. Ask it a few questions to ensure it return results.<br>

![Alt text](/media/ragchatterminal.png "RAGCHAT Terminal")

<br>

## Success Criteria

1. Type this question into the prompt window, "What is the out-of-pocket maximum for the Northwind Standard plan?".  The returned answer should mention $6,000 per person per year.

1. Open Foundry Project to see model deployments.  Search for 'gpt-4o-mini' as a model name

1. Click on Monitor icon and click on the Resource Usage Tab.  For Model deployment, select ```text-embedding-3-large```.  You should see numbers for Total requests and Total Token count
<br>

## Continue to Challenge 1

After you complete all the success criteria, follow the steps in the [Challenge 1 -- Responsible AI](/code/1_challenge/README.md) to run the workshop. 
<br>

## Related Azure Technology
* Application Insights
* Microsoft Foundry
* Container App & Registry
* Azure AI Search
* Azure Storage Account
<br>

## Resources
* Video series called, RAG Deep Dive https://aka.ms/ragdeepdive 
* Alernative RAGCHAT repo https://aka.ms/ragchat#guidance   
* RAG Resources from RAGCHAT Repo https://aka.ms/ragchat#resources

<br>
<br>

# CHALLENGE 0 COMPLETE!!!!!

<br>
<br>

# Contributors to this Microhack

We are grateful to the hard-work and thought leadership done by Pamela Fox and Matt Gotteiner. We were inspired and informed by their work.  We have sampled from their https://aka.ms/ragchat repo and studied their podcast series RAG Deep dive http://aka.ms/ragdeepdive.  We highly recommend to watch this content when preparing your applications to move into production.


<!-- We have built our own code set for easier maintenance and to highlight Trustworthy AI principles than RAG based applications.  All data and code lives in this repo for the Microhack and don't need external data from other repos.  We share learning resources from RAGCHAT application since it does a great job of highlighting evaluation principles and code samples.  The repo leverages as of Jan 2026 Microsoft Foundry Classic since it is in GA.  When Foundry New Portal is moved into GA we will refactor the repo.  -->
