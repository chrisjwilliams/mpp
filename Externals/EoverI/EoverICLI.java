import java.util.*;
import java.util.concurrent.TimeUnit;
import java.io.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.net.*;
import java.util.Arrays;
import org.apache.log4j.Logger;

import com.eoveri.zeeli.BoxInstance;
import com.eoveri.zeeli.BoxOffer;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2Region;
import com.eoveri.zeeli.provider.ec2api.types.EC2SecurityController;
import com.eoveri.zeeli.provider.ec2api.types.description.security.firewall.EC2IpProtocol;
import com.eoveri.zeeli.provider.ec2api.types.description.security.EC2BoxLoginKey;
import com.eoveri.zeeli.provider.ec2api.types.description.security.firewall.EC2SecurityGroupId;
import com.eoveri.zeeli.provider.ec2api.types.exception.KeyGenerateFailureException;
import com.eoveri.zeeli.auth.CloudCredential;
import com.eoveri.zeeli.auth.managed.ManagedProviderCredential;
import com.eoveri.zeeli.auth.store.TestCredentialStore;
import com.eoveri.zeeli.exception.CouldNotInstantiateException;
import com.eoveri.zeeli.exception.CouldNotAcquireInstanceException;
import com.eoveri.zeeli.exception.NoSuitableOperatingSystemAvailableException;
import com.eoveri.zeeli.managed.client.api.user.CallEnvironment;
import com.eoveri.zeeli.id.BoxId;
import com.eoveri.zeeli.id.ZeelId;
import com.eoveri.zeeli.provider.ec2api.types.EC2BoxProvider;
import com.eoveri.zeeli.provider.ec2api.types.requirement.os.EC2AMIRequirement;
import com.eoveri.zeeli.provider.ec2api.types.requirement.template.EC2InstanceTypeNameRestriction;
import com.eoveri.zeeli.provider.flessr.types.description.FlessrRegion;
import com.eoveri.zeeli.provider.ec2api.types.managed.ManagedEC2BoxProviderFactory;
import com.eoveri.zeeli.provider.ec2api.types.EC2OperatingSystem;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2BoxInstance;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2BoxTemplate;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2InstanceType;
import com.eoveri.zeeli.restrictions.OperatingSystemRestriction;
import com.eoveri.zeeli.restrictions.TemplateRestriction;
import com.eoveri.zeeli.provider.ec2api.types.description.EC2BoxInstance;
import com.eoveri.zeeli.provider.ec2api.types.EC2BasicBoxProvider;
import com.eoveri.zeeli.status.BoxState;
import com.eoveri.zeeli.status.DiscardResult;
import com.eoveri.zeeli.status.GetBoxStateResult;

import com.eoveri.zeeli.managed.client.impl.base.ClientManagedControlAgent;
import com.eoveri.zeeli.exec.ControlAgent;
import com.eoveri.zeeli.exec.ExecResult;
import com.eoveri.zeeli.exec.FileTransferResult;

import com.eoveri.std.DataType.*;
import com.eoveri.std.threading.Timeout;
import com.eoveri.std.util.ListUtility;
import com.eoveri.std.util.url.URLEncoding;
import com.eoveri.std.xstream.XSHelper;

import com.eoveri.zeeli.auth.managed.ManagedProviderLocalPEMCredential;

import org.apache.commons.cli.BasicParser;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.OptionBuilder;
import org.apache.commons.cli.Option;
import org.apache.commons.cli.OptionGroup;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.ParseException;

public class EoverICLI {

    private static transient final Logger log = Logger.getLogger(EoverICLI.class);

    private static String PROVIDER_ID;

    static {
       //PROVIDER_ID = "{https://catalogue.cloudprovider.service.eoveri.com:8443/catalogue/FindProvider}flessr";
       PROVIDER_ID = "{https://catalogue.cloudprovider.service.eoveri.com:8443/catalogue/FindProvider}flessr-2011-02-18";
    }

    private final EC2BoxProvider provider;


    /**
     * Constructor
     */
    public EoverICLI(EC2BoxProvider provider) {
        this.provider = provider;
    }

    /*
     *  provision a new instance
     */
    protected BoxInstance provision(
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
     *  Setup account information ( only do this one time )
     */
    public void configureAccount( String ingress_idr ) {
        if( provider instanceof EC2BoxProvider ) {
            // Generate a new key called “default” for each Region (keys are scoped to a Region)
            final EC2SecurityController controller = provider.getSecurityController();
            final String keyName = "default";
            for (EC2Region region: provider.getRegions()) {
                try {
                    controller.generateLoginKey(region, keyName); // Generate the key
                }
                catch( KeyGenerateFailureException e) {
                    System.err.println( "error generationg key for region" + region.toString() + " : " + e.getMessage() );
                }
            }
            // Allow 1.2.3.4 via the default security group on each region in this provider
            final String defaultGroupName = "default";
            final int SSH_PORT = 22;
            final EC2IpProtocol proto = EC2IpProtocol.TCP;
            if( ingress_idr == "" ) ingress_idr = "193.61.123.0/24"; // EoverI network default
            final InetSubnet subnet = new InetSubnet(ingress_idr); 
            try {
                for (EC2SecurityGroupId group: controller.getAllSecurityGroupIds()) {
                    if (group.getId().equalsIgnoreCase(defaultGroupName)) {
                        controller.authoriseCIDRIngress(group, proto, SSH_PORT, SSH_PORT, subnet);
                    }
                }
            } catch ( Exception e ) {
                System.err.println( "error getting security groups:" + e.getMessage() );
            }
        }
    }

    /**
     * Print all visible instances
     */
    protected void showAvailableInstances(boolean verbose) {
       // Display the currently running instances
        EC2BoxInstance[] boxes = (EC2BoxInstance[])provider.getAllInstances();

        for (EC2BoxInstance box : boxes) {
            if (verbose) {
                System.out.println("Id: " + encodeId(box.getId()));
                System.out.println("\tType: " + box.getInstanceType().getTypeName());

                for (InetAddress ip : box.getIPs())
                    System.out.println("\tIP: " + ip.getHostAddress());

                System.out.println("\tCountry: " + box.getLocation().getCountry());
                System.out.println("\tStatus: " + box.getBoxState());
                System.out.println();
            }
            else {
                System.out.println(encodeId(box.getId()));
            }
        }

        System.out.println("Running Instances: " + boxes.length);
        System.out.println();
    }


    protected final boolean discardInstance(BoxInstance instance) {

        DiscardResult result = provider.discard(instance);

        System.out.println("Requested discard of " + instance.getId());
        System.out.println("\tDiscard success: " + result.success);
        System.out.println("\tDiscard message: " + result.statusMsg);
        System.out.println();
        return result.success;
    }

    protected BoxId getBoxId( String instanceId ) {
        return decodeBoxId(instanceId);
    }

    protected ControlAgent getAgent( String instanceId, String user ) throws Exception {
        return provider.getController().getControlAgent( getBoxId(instanceId), user);
    }

    //
    // ----- Public methods ------------------------------------
    //
    protected boolean start(String imageId, String instanceType ) {

        final TemplateRestriction hw = new EC2InstanceTypeNameRestriction(instanceType);
        final OperatingSystemRestriction sw = new EC2AMIRequirement(imageId);
        try {
            BoxInstance instance = provision(hw, sw);

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
                // System.out.println("SSH key: " + instance.getLoginKey());
                System.out.println("id:" + encodeId(instance.getId()));

                // generate a default key for accessing the machine
                /*
                if( instance instanceof EC2BoxInstance ) {
                    EC2SecurityController sc = provider.getSecurityController();
                    EC2BoxLoginKey key = sc.generateLoginKey( ((EC2BoxInstance)instance).getRegion(), encodeId(instance.getId()) );
                    sc.setDefaultKey( key.getRef() );
                    System.out.println("key:" + key.toString() );
                }
                */
                return true;
            }
            else {
                // Provision+Start timed out
                // Throw away the resource
                discardInstance(instance);
                return false;
            }
        }
        catch (Exception e) {
            System.err.println("Could not start instance:" + e.getMessage());
            return false;
        }
    }


    // Encodes an Id so it does not have any spaces
    private static String encodeId(ZeelId id) {
        return URLEncoding.encode(id.getValue());
    }


    // Decodes a previously-encoded id
    private static BoxId decodeBoxId(final String encoded) {
        final String decoded = URLEncoding.decode(encoded);
        return new BoxId(decoded);
    }


    public final boolean stop( String instanceId ) {
        try {
            BoxInstance instance = provider.getInstanceById( getBoxId(instanceId) );
            return discardInstance(instance);
        }
        catch (CouldNotAcquireInstanceException e) {
            System.err.println("Unknown instance: " + instanceId);
            return false;
        }
    }

    public void status( String instanceId ) {

        try {
            BoxInstance instance = provider.getInstanceById( getBoxId(instanceId) );
            final BoxState state = instance.getBoxState();
            switch (state) {
                case RUNNING:
                    // box is running
                    System.out.println("status: running");
                    break;
                case FAILURE:
                    System.out.println("status: failed");
                    break;
                case STOPPED:
                    System.out.println("status: stopped");
                    break;
                default:
                    System.out.println("status: unknown (" + state  + ")");
            }
        }
        catch (CouldNotAcquireInstanceException e) {
            System.out.println("status: unknown");
        }
        catch ( Exception e ) {
            System.out.println("status: unknown");
            System.err.println( e.getMessage() );
        }
    }


    public final ExecResult runCmd(String boxId, String user, String[] cmds ) throws Exception, CouldNotAcquireInstanceException {
        ControlAgent agent = getAgent( boxId, user );
        if (cmds.length == 1) {
            cmds[0].trim();
            // a quoted argument needs to be broken into tokens first
            //cmds[0] = cmds[0].substring(1, cmds[0].length() - 1); // strip the quotes
            String regex = "\"([^\"]*)\"|(\\S+)";
            Matcher m = Pattern.compile(regex).matcher(cmds[0]);

            List<String> list = new ArrayList<String>();
            while (m.find()) {
                String token;
                if (m.group(1) != null) {
                     // quoted token
                     token = m.group(1);
                }
                else {
                     token  =m.group(2);
                }
                list.add(token);
                //System.out.println("token command=<" + token +"<");
            }
            String[] newcmds = list.toArray( new String[ list.size() ] );
            return agent.exec( newcmds );
        }
        return agent.exec( cmds );
    }

    public final FileTransferResult downloadFile( String boxId, String user, 
                            java.io.File remoteFile, java.io.File localFile ) throws Exception, CouldNotAcquireInstanceException {
        ControlAgent agent = getAgent( boxId, user );
        return agent.downloadFile( remoteFile, localFile );
    }

    public final FileTransferResult uploadFile( String boxId, String user, 
                            java.io.File localFile, java.io.File remoteFile ) throws Exception, CouldNotAcquireInstanceException {
        ControlAgent agent = getAgent( boxId, user );
        return agent.uploadFile( localFile, remoteFile );
    }

    /*
     * Private classes to manage the command line
     */

    private static class CLICommand {
        public String description;
        public String command;
        public String args;


        public CLICommand(String cmd, String args, String description) {
            command = cmd;
            this.args = args;
            this.description = description;
        }


        String usage() {
            return "usage: " + command + " " + args;
        }
    }

    private static class CLICommands {
        private TreeMap<String, CLICommand> allowedCommands;


        public CLICommands() {
            allowedCommands = new TreeMap<String, CLICommand>();
        }


        public void add(CLICommand cmd) {
            allowedCommands.put(cmd.command, cmd);
        }


        public final String usage(String cmd) {
            if (allowedCommands.containsKey(cmd)) {
                return allowedCommands.get(cmd).usage();
            }
            return "";
        }


        public final boolean hasCommand(String cmd) {
            return allowedCommands.containsKey(cmd);
        }


        public final Collection<CLICommand> commands() {
            return allowedCommands.values();
        }


        public final String help(String cmd) {
            if(allowedCommands.containsKey(cmd)) {
                return allowedCommands.get(cmd).description;
            }
            return "";
        }
    }


    /* print to stdout the exec result in XML format
     * @param the ExecResult object to print
     */
    public final void printExecResult(ExecResult r) {
        System.out.println(r.getStdout());
        System.err.println(r.getStderr());
    }


    // --- Command line interface Wrapper to the API
    public static void main(String[] argv) {

        // allowed command definition
        //List<CLICommand> allowedCommands = new ArrayList<CLICommand>();
        CLICommands allowedCommands = new CLICommands();
        allowedCommands.add(new CLICommand("list", "", "list available instances") );
        allowedCommands.add(new CLICommand("start", "<image> <hw_template>", "start up a new instance") );
        allowedCommands.add(new CLICommand("stop", "<instanceId>", 
                                            "stop the specified instance") );
        allowedCommands.add(new CLICommand("status","<instanceId>", 
                                            "print out status and informatin for a specified instance") );
        allowedCommands.add(new CLICommand("execute", "<instanceId> <username> <cmd>",
                                            "execute the provided command as the specifed user of the specified instance."
                                           ) );
        allowedCommands.add(new CLICommand("upload", "<instanceId> <username> <src_file> <destination_file> [<src_file> <destination_file> ...]",
                                            "upload a file to the specified instance") );
        allowedCommands.add(new CLICommand("download","<instanceId> <username> <src_file> <destination_file>",
                                            "download a file from the specified instance") );
        allowedCommands.add(new CLICommand("configure_account","<ingress_idr>",
                                            "set up access permission for your account. By default will allow access only to internal EoverI commands to each instance (ingress_idr=193.61.123.0/24).") );

        // define defaults
        String pemName = "me.pem";
        String trustName = "trust.pem";

        // define command line options
        Options opt = new Options();
        opt.addOption("h", false, "Print out help");
        opt.addOption("trust", false, "specify a trust certificate");

        opt.addOption(OptionBuilder.withArgName("file").hasArg().withDescription(
            "specify a trust certificate (default \"" + trustName + "\")").create("trust"));

        opt.addOption(OptionBuilder.withArgName("file").hasArg().withDescription(
            "specify a pem user certificate (default \"" + pemName + "\")").create("pem"));
        // commands
        //OptionGroup commands = new OptionGroup();
        //commands.addOption( OptionBuilder.withDescription( "list all instances")
        //                                .create("list") );
        //commands.setRequired(true);
        //opt.addOptionGroup(commands);

        BasicParser parser = new BasicParser();
        String[] args = argv; // remaining args after options have been stripped out
        try {
            CommandLine cl = parser.parse(opt, argv, true );
            args = cl.getArgs();
            if (cl.hasOption('h')) {
                HelpFormatter f = new HelpFormatter();
                f.printHelp("zeel-cli [options] {command} [command-options]", opt );
                System.out.println("Commands:\n");
                for (CLICommand cmd : allowedCommands.commands() ) {
                    System.out.println(" " + cmd.command + " " + cmd.args + "\n\t\t" + cmd.description );
                }
                System.out.println("\t");
                System.exit(0);
            }
            if( cl.hasOption("pem") ) {
                pemName = cl.getOptionValue( "pem" );
            }
            if( cl.hasOption("trust") ) {
                trustName = cl.getOptionValue( "trust" );
            }
        }
        catch( ParseException e ) {
            System.err.println( e.getMessage() );
            System.exit(1);
        }


        if( args.length <= 0 ) {
            System.out.println("No command given.");
            System.exit(1);
        }

        // Process the command
        String cmd = args[0];
        if( ! allowedCommands.hasCommand( cmd ) ) {
            System.err.println("unknown command: " + cmd);
            System.err.println("-h option for help" );
            System.exit(1);
        }
        //

        // Setup the provider
        final EC2BasicBoxProvider provider;
        {
            final ManagedProviderCredential CREDENTIAL;
            {
                final File trust = new File(trustName);
                final File pem = new File(pemName);
                CREDENTIAL = new ManagedProviderLocalPEMCredential(pem, trust);
            }

        // private static ManagedProviderCredential CREDENTIAL;
            {
                ManagedEC2BoxProviderFactory factory = new ManagedEC2BoxProviderFactory(
                    (ManagedProviderCredential) CREDENTIAL, 
                    new CallEnvironment());
                // factory exisance scope
                //ManagedFlessrBoxProviderFactory factory = new ManagedFlessrBoxProviderFactory(
                //        (ManagedProviderCredential) CREDENTIAL,
                //        new CallEnvironment());
                provider = factory.getProvider(PROVIDER_ID);
            }
        }

        EoverICLI cli = new EoverICLI(provider);

        try {
            if( cmd.equalsIgnoreCase("list") ) {
                cli.showAvailableInstances(false);
            }
            else if ( cmd.equalsIgnoreCase("start") ) {
                if( args.length <= 2 ) {
                    System.out.println(allowedCommands.usage("start"));
                    System.exit(1);
                }
                System.out.println("start("+args[1]+","+args[2]+")");
                cli.start(args[1],args[2]);
            }
            else if ( cmd.equalsIgnoreCase("stop") ) {
                if( args.length <= 1 ) {
                    System.out.println(allowedCommands.usage("stop"));
                    System.exit(1);
                }
                for(int i=1; i<args.length; ++i) {
                    cli.stop(args[i]);
                }
            }
            else if ( cmd.equalsIgnoreCase("execute") ) {
                if( args.length <= 3 ) {
                    System.out.println(allowedCommands.usage("execute"));
                    System.exit(1);
                }
                String id = args[1];
                String user = args[2];
                String[] cmds = new String[ args.length - 3];
                System.arraycopy(args, 3, cmds, 0, args.length - 3);

                ExecResult r = cli.runCmd( id, user, cmds );
                if( r.getReturnCode() != 0 ) {
                    System.err.print("error executing command: ");
                    String sep="\"";
                    for(int i=0; i < cmds.length; ++i ) {
                        System.err.print(sep + cmds[i] );
                        sep=" ";
                    }
                    System.err.println("\"");
                }
                cli.printExecResult( r );
                System.exit( r.getReturnCode() );

            }
            else if ( cmd.equalsIgnoreCase("configure_account") ) {
                String ingress_idr;
                if( args.length > 1 ) {
                    System.out.println(allowedCommands.usage("configure_account"));
                }
                if( args.length == 1 ) {
                    ingress_idr="";
                }
                else { ingress_idr = args[1]; }
                cli.configureAccount(ingress_idr);
            }
            else if ( cmd.equalsIgnoreCase("status") ) {
                if( args.length <= 1 ) {
                    System.out.println(allowedCommands.usage("status"));
                    System.exit(1);
                }
                cli.status(args[1]);
            }
            else if ( cmd.equalsIgnoreCase("upload") ) {
                if( args.length <= 4 ) {
                    System.out.println(allowedCommands.usage("upload"));
                    System.exit(1);
                }
                String id = args[1];
                String user = args[2];
                for( int i = 3; i < args.length; i += 2 ) {
                    FileTransferResult r = cli.uploadFile( id, user, new File(args[i]) , new File(args[i+1]) );
                    if( ! r.getSuccess() ) {
                        System.err.println( r.getMessage() );
                        System.exit( 1 );
                    }
                }
                System.exit( 0 );
            }
            else if ( cmd.equalsIgnoreCase("download") ) {
                if( args.length <= 4 ) {
                    System.out.println(allowedCommands.usage("upload"));
                    System.exit(1);
                }
                String id = args[1];
                String user = args[2];
                FileTransferResult r = cli.downloadFile(id, user, new File(args[3]), new File(args[4]) );
                if(!r.getSuccess()) {
                    System.err.println(r.getMessage());
                    System.exit(1);
                }
                System.exit(0);
            }
            else {
                System.out.println("Unknown command : " + cmd );
                System.exit(1);
            }
        }
        catch( IllegalArgumentException e ) {
            System.err.println("Illegal Argument:" + e.getMessage() );
            System.exit(1);
        }
        catch( CouldNotAcquireInstanceException e ) {
            System.err.println("Could not aquire instance:" + e.getMessage() );
            System.exit(1);
        }
        catch( Exception e ) {
            System.err.println("Error:" + e.getMessage() );
            System.exit(1);
        }
    }
}
