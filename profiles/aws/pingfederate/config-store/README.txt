Static configuration Overrides
------------------------------

These are settings that will override values set either by restoring a configuration backup
or previously set via the API. Only setting supported by the configStore endpoint may be
changed via this mechanism.

Only files with a '.json' suffix will be processed, and they will be processed in collating
sequence order. That is the order returned by the command "ls *.json | sort"

Startup Sequencing
------------------

If a configuration backup exists, it will be downloaded and placed in the drop-in deployer 
directory for PingFederate to deploy on startup as was the case before this hook was 
implemented. 
 
During the startup process, PingFederate will be manually started by the config store hook as 
a background process running on localhost only. This prevents external access while the server 
is in an indeterminate state. It is also necessary to deploy the configuration archive before 
applying static configuration. Since this local server will be shut down before the hook 
returns this approach automatically deals with any settings that require a restart to activate.

On initial server start the config store hook is called from the hook '18-setup-sequence.sh.pre', 
this is necessary because the license must be in place to use the PingFederate API. On subsequent 
restarts, it is called from '20-restart-sequence.sh.pre' immediately prior to calling the 
'22-upgrade-server.sh' hook. This ensures the updated settings go through the upgrade process. 
Of course it may be necessary to modify the setting in the cluster state repository to be 
compatible with the upgraded configuration prior to the next server restart.

Parameters
----------

The following parameters are required to change a value.

   bundle:     The name of the file in the config-store directory containing the value.

   method:     The operation to perform, valid values are 'put' or 'delete' which may 
               be abbreviated to 'del'.

   payload:    For the 'put' operation, payload as it would appear if the change was 
               being applied via the API. For 'delete' operations the same format is
               used for simplicity but only the id value is actually used and the 
               payload is otherwise discarded.

               See the API documentation for further details.  	


Examples
--------

This example would delete the minimum number of special characters that must appear in the 
administrator password, in this particular case this would revert the value to its default.  

   {
      "bundle"  :  "password-rules",
      "method"  :  "del",
      "payload" :
      {
         "id": "minSpecial",
         "stringValue": "0",
         "type": "STRING"
      }
   }

This is equivalent to the above.

   {
      "bundle"  :  "password-rules",
      "method"  :  "del",
      "payload" :  
      {
         "id": "minSpecial"
      }
   }


This example would turn off support for ONGL expressions, don't run this example as it would 
disable administrator login. This specific value is set to 'true' by the bootstrap server 
profile when the environment is initially created.  

   {
      "bundle"  :  "org.sourceid.common.ExpressionManager",
      "method"  :  "put",
      "payload" :  
      {
         "id": "evaluateExpressions",
         "stringValue": "false",
         "type": "STRING"
      }
   }

