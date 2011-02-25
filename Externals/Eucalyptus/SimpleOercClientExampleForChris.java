package com.eoveri.test;

import java.util.*;
import java.util.concurrent.TimeUnit;
import java.io.*;
import java.net.*;
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

public class SimpleOercClientExampleForChris {
	public static void main(String[] args) throws Exception {
		// Replace this with a method to set up your credential (e.g. from the OeRCDemo.java code)
		ManagedProviderCredential credential = TestCredentialStore.getCredentialStore().get(
		    ManagedProviderCredential.class,
		    "escience-pwright");

		final OeRCBoxProvider provider = new ManagedOeRCBoxProviderFactory(credential).getProvider("oerc-as-pw");
		
		// Call some entry point (e.g. provision, isRunning, discard
	}


	/**
	 * Entry point for the "provision" operation<br />
	 * Provisions a single resource and returns immediately (potentially before the IP address is available)
	 * 
	 * @param provider the provider
	 * @param instanceType the name of the instance type (e.g. "m1.small")
	 * @param imageId the EMI of the Operating System to run
	 * @throws Exception if the provisioning operation fails
	 */
	public static void provision(OeRCBoxProvider provider, String instanceType, String imageId) throws Exception {
		final TemplateRestriction hw = new EC2InstanceTypeRestriction(getInstanceType(instanceType));
		final OperatingSystemRestriction sw = new EC2AMIRequirement(imageId);

		provision(provider, hw, sw);
	}


	/**
	 * Entry point for the "is running" operation
	 * 
	 * @param provider the provider
	 * @param instanceId the instance id value
	 */
	public static void isRunning(OeRCBoxProvider provider, String instanceId) {
		BoxId boxId = getBoxId(provider, instanceId);

		isRunning(provider, boxId);
	}


	/**
	 * Entry point for the "discard" operation which throws away a Box
	 * 
	 * @param provider the provider
	 * @param instanceId the instance id value
	 */
	public static void discard(OeRCBoxProvider provider, String instanceId) {
		BoxId boxId = getBoxId(provider, instanceId);

		discard(provider, boxId);
	}


	protected static OeRCInstanceType getInstanceType(String name) {
		for (OeRCInstanceType instanceType : OeRCInstanceType.ALL) {
			if (instanceType.getTypeName().equalsIgnoreCase(name)) {
				return instanceType;
			}
		}

		throw new IllegalArgumentException("OeRCInstanceType does not know instance type " + name);
	}


	public static void provision(
	                             final OeRCBoxProvider provider,
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

		/*
		// Wait for up to 20 minutes for the box to leave the PENDING_ALLOCATION or ALLOCATING state
		GetBoxStateResult finalState = provider.getController().waitForBoxStateChange(
		    id,
		    new Timeout(20, TimeUnit.MINUTES),
		    BoxState.PENDING_ALLOCATION,
		    BoxState.ALLOCATING);

		// Get an up-to-date object describing the instance
		instance = provider.getInstanceById(id);
		*/

	}


	protected static BoxId getBoxId(OeRCBoxProvider provider, String instanceId) {
		BoxId boxId = new EC2BoxId(OeRCRegion.OERC1, instanceId);

		return boxId;
	}


	public static void isRunning(OeRCBoxProvider provider, BoxId boxId) {
		try {
			BoxInstance instance = provider.getInstanceById(boxId);

			final BoxState state = instance.getBoxState();

			switch (state) {
				case RUNNING:
					// box is running
					// will have IP addresses now
					final InetAddress[] ips = instance.getIPs();

					System.out.println("Box is running");
					break;
				case FAILURE:
					System.out.println("Box has failed");
					break;
				case STOPPED:
					System.out.println("Box is stopped");
					break;
			}
		}
		catch (CouldNotAcquireInstanceException e) {
			System.err.println("Unknown instance: " + boxId);
		}
	}


	public static void discard(OeRCBoxProvider provider, BoxId boxId) {
		final DiscardResult result = provider.discard(boxId);

		if (result.success) {
			// box discarded
		}
		else {
			System.err.println("Failed to discard. Error was: " + result.getStatusMsg());
		}
	}
}
