# -*- coding: utf-8 -*-
from plone.app.robotframework.testing import REMOTE_LIBRARY_BUNDLE_FIXTURE
from plone.app.testing import applyProfile
from plone.app.testing import FunctionalTesting
from plone.app.testing import IntegrationTesting
from plone.app.testing import PLONE_FIXTURE
from plone.app.testing import PloneSandboxLayer
from plone.testing import z2

import kitconcept.policy


class KitconceptPolicyLayer(PloneSandboxLayer):

    defaultBases = (PLONE_FIXTURE,)

    def setUpZope(self, app, configurationContext):
        self.loadZCML(package=kitconcept.policy)

    def setUpPloneSite(self, portal):
        applyProfile(portal, 'kitconcept.policy:default')


KITCONCEPT_POLICY_FIXTURE = KitconceptPolicyLayer()


KITCONCEPT_POLICY_INTEGRATION_TESTING = IntegrationTesting(
    bases=(KITCONCEPT_POLICY_FIXTURE,),
    name='KitconceptPolicyLayer:IntegrationTesting'
)


KITCONCEPT_POLICY_FUNCTIONAL_TESTING = FunctionalTesting(
    bases=(KITCONCEPT_POLICY_FIXTURE,),
    name='KitconceptPolicyLayer:FunctionalTesting'
)


KITCONCEPT_POLICY_ACCEPTANCE_TESTING = FunctionalTesting(
    bases=(
        KITCONCEPT_POLICY_FIXTURE,
        REMOTE_LIBRARY_BUNDLE_FIXTURE,
        z2.ZSERVER_FIXTURE
    ),
    name='KitconceptPolicyLayer:AcceptanceTesting'
)
