import java.util.*;
import java.util.concurrent.TimeUnit;
import java.io.*;
import java.net.*;
import java.util.Arrays;
import org.apache.log4j.Logger;

import com.eoveri.zeeli.BoxInstance;
import com.eoveri.zeeli.BoxOffer;
import com.eoveri.zeeli.auth.EucalyptusCredential;
import com.eoveri.zeeli.auth.managed.ManagedProviderCredential;
import com.eoveri.zeeli.auth.store.TestCredentialStore;
import com.eoveri.zeeli.exception.CouldNotAcquireInstanceException;
import com.eoveri.zeeli.id.BoxId;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2BoxId;
import com.eoveri.zeeli.provider.ec2api.types.requirement.os.EC2AMIRequirement;
import com.eoveri.zeeli.provider.ec2api.types.requirement.template.EC2InstanceTypeRestriction;
import com.eoveri.zeeli.provider.oerc.types.OeRCBoxProvider;
import com.eoveri.zeeli.provider.oerc.types.description.OeRCInstanceType;
import com.eoveri.zeeli.provider.oerc.types.description.OeRCRegion;
import com.eoveri.zeeli.provider.oerc.types.managed.ManagedOeRCBoxProviderFactory;
import com.eoveri.zeeli.restrictions.OperatingSystemRestriction;
import com.eoveri.zeeli.restrictions.TemplateRestriction;
import com.eoveri.zeeli.status.BoxState;
import com.eoveri.zeeli.status.DiscardResult;
import com.eoveri.zeeli.status.GetBoxStateResult;

import com.eoveri.std.DataType.*;
import com.eoveri.std.threading.Timeout;
import com.eoveri.std.util.ListUtility;
import com.eoveri.std.xstream.XSHelper;

import com.eoveri.zeeli.auth.managed.ManagedProviderLocalPEMCredential;


public class EucalyptusCLI {

    private static transient final Logger log = Logger.getLogger(EucalyptusCLI.class);

    private static ManagedProviderCredential CREDENTIAL;
    private static String PROVIDER_ID;

    static {
       CREDENTIAL = new ManagedProviderLocalPEMCredential(new File("me.pem"), new File("trust.pem"));
       PROVIDER_ID = "{https://catalogue.cloudprovider.service.eoveri.com:8443/catalogue/FindProvider}oerc-as-pw";
    }

    private final OeRCBoxProvider provider;

    /**
   _ * Constructor
   _ */
    public EucalyptusCLI(OeRCBoxProvider provider) {
              this.provider = provider;
    }

    protected static OeRCInstanceType getInstanceType(String name) {
        for (OeRCInstanceType instanceType : OeRCInstanceType.ALL) {
            if (instanceType.getTypeName().equalsIgnoreCase(name)) {
                return instanceType;
            }
        }
        throw new IllegalArgumentException("OeRCInstanceType does not know instance type " + name);
    }

    /*
     *  provision a new instance
     */
    public BoxInstance provision(
                                 final TemplateRestriction hwRestriction,
                                 final OperatingSystemRestriction osRestriction) throws Exception {

            TemplateRestriction[] hwRestrictions = new TemplateRestriction[] { hwRestriction };
            OperatingSystemRestriction[] swRestrictions = new OperatingSystemRestriction[] { osRestriction };

            BoxOffer offer = provider.getOfferProvider().find(hwRestrictions, swRestrictions).getCheapest();

            // reserve and instantiate one instance of the BoxOffer
            BoxInstance[] instances = provider.instantiate(provider.reserve(offer, 1));
            assert (instances.length == 1);
            BoxInstance instance = instances[0];

            // Have instance Id now, can print out data
            // Won't necessarily have IP address yet

            BoxId id = instance.getId();

            // Could wait here for the instance to become available
            // Remember, if something goes wrong we should discard the box using provider.discard(id)

            // Wait for up to 20 minutes for the box to leave the PENDING_ALLOCATION or ALLOCATING state
            /*
            GetBoxStateResult finalState = provider.getController().waitForBoxStateChange(
                id,
                new Timeout(20, TimeUnit.MINUTES),
                BoxState.PENDING_ALLOCATION,
                BoxState.ALLOCATING);

            // Get an up-to-date object describing the instance
            instance = provider.getInstanceById(id);
            */

            return instance;

    }

    /**
   _ * Print all visible instances
   _ */
    protected void showAvailableInstances() {
       // Display the currently running instances
       BoxInstance[] boxes = provider.getAllInstances();

       for (BoxInstance box : boxes) {
          System.out.println("Box " + box.getId());

          for (InetAddress ip : box.getIPs())
              System.out.println("\tIP: " + ip.getHostAddress());

          System.out.println("\tCountry: " + box.getLocation().getCountry());
          System.out.println("\tStatus: " + box.getBoxState());

          System.out.println();
       }

       System.out.println("Running Instances: " + boxes.length);
       System.out.println();
    }

    protected final boolean discardInstance( BoxInstance instance ) {
          // Now let's discard the resource
          System.out.println("Discarding the new instance");

          DiscardResult result = provider.discard(instance);

          System.out.println("Requested discard of " + instance.getId());
          System.out.println("\tDiscard success: " + result.success);
          System.out.println("\tDiscard message: " + result.statusMsg);
          System.out.println();
          return result.success;
    }

    protected BoxId getBoxId( String instanceId ) {
        BoxId boxId = new EC2BoxId(OeRCRegion.OERC1, instanceId);
        return boxId;
    }


    protected boolean start( String instanceType, String imageId ) {

        final TemplateRestriction hw = new EC2InstanceTypeRestriction(getInstanceType(instanceType));
        final OperatingSystemRestriction sw = new EC2AMIRequirement(imageId);
        try {
            BoxInstance instance = provision( hw, sw );

            // Wait for up to 20 minutes for the box to leave the PENDING_ALLOCATION or ALLOCATING state
            GetBoxStateResult finalState = provider.getController().waitForBoxStateChange(
                    instance.getId(),
                    new Timeout(20, TimeUnit.MINUTES),
                    BoxState.PENDING_ALLOCATION,
                    BoxState.ALLOCATING);

            // get the lastest status info

            if( finalState.isSuccess() ) {
                // Box has started
                // Refresh the snapshot of the box data
                // so we can print out the instance id
                instance = provider.getInstanceById(instance.getId());
                System.out.println(instance.getId());
                return true;
            }
            else {
                // Provision+Start timed out
                // Throw away the resource
                discardInstance(instance);
                return false;
            }
        }
        catch(Exception e)
        {
            System.err.println("Could not start instance:" + e.getMessage() );
            return false;
        } 
    }

    protected final boolean stop( String instanceId ) {
        try {
            BoxInstance instance = provider.getInstanceById( getBoxId(instanceId) );
            return discardInstance(instance);
        }
        catch (CouldNotAcquireInstanceException e) {
            System.err.println("Unknown instance: " + instanceId);
            return false;
        }
    }

    protected void runCmd( String boxId, String[] cmds ) {
    }

    public static void main(String[] args) {
        if( args.length <= 0 ) {
            System.out.println("No command given.");
            System.exit(1);
        }
        // Setup the OERC provider
        final OeRCBoxProvider provider;
        {
            ManagedOeRCBoxProviderFactory factory = new ManagedOeRCBoxProviderFactory((ManagedProviderCredential) CREDENTIAL);
            provider = factory.getProvider(PROVIDER_ID);
        }
        EucalyptusCLI cli = new EucalyptusCLI(provider);

        // Process the command
        String cmd = args[0];
        if( cmd.equalsIgnoreCase("list") ) {
           cli.showAvailableInstances();
        }
        else if ( cmd.equalsIgnoreCase("start") ) {
            if( args.length <= 1 ) {
                System.out.println("No machine identifier given.");
                System.exit(1);
            }
            cli.start(args[0],args[1]);
        }
        else if ( cmd.equalsIgnoreCase("stop") ) {
            if( args.length <= 1 ) {
                System.out.println("No machine identifier given.");
                System.exit(1);
            }
            cli.stop(args[1]);
        }
        else if ( cmd.equalsIgnoreCase("execute") ) {
            if( args.length <= 1 ) {
                System.out.println("No machine identifier given.");
                System.exit(1);
            }
            String[] cmds = Arrays.copyOfRange(args, 1, args.length-1 );
            cli.runCmd(args[0], cmds );
        }
        else if ( cmd.equalsIgnoreCase("status") ) {
            if( args.length <= 1 ) {
                System.out.println("No machine identifier given.");
                System.exit(1);
            }
            cli.status(args[1]);
        }
        else if ( cmd.equalsIgnoreCase("ip") ) {
            if( args.length <= 1 ) {
                System.out.println("No machine identifier given.");
                System.exit(1);
            }
        }
        else {
            System.out.println("Unknown command : " + cmd );
            System.exit(1);
        }
    }
}
