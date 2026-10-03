"""Exact reviewed influence/region guards and original binary retention."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np

from constraints import RigError
from correct_skin_weights import ROOT, REGIONS, apply, redirect, region_amount, sha
from glb_io import accessor_values, read_glb


class WeightCorrectionTests(unittest.TestCase):
    def test_arm_transfer_keeps_other_source_influences(self):
        names=["Head","RightUpperArm","UpperTorso","Aux_neck"]
        joints,weights=redirect([1,2,3,0],[.5,.3,.2,0.],names,"Head",.6)
        actual=dict(zip(joints,weights))
        self.assertAlmostEqual(actual[1],.2)
        self.assertAlmostEqual(actual[0],.3)
        self.assertEqual(actual[2],.3)
        self.assertEqual(actual[3],.2)
        with self.assertRaises(RigError):
            redirect([1,2,3,4],[.4,.3,.2,.1],names+["LowerTorso"],"Head",.5)

    def test_explicit_whole_braid_transfer_keeps_total_without_arm_requirement(self):
        joints,weights=redirect([1,2,3,0],[.5,.3,.2,0.],["Head","UpperTorso","Aux_neck","LowerTorso"],"Head",1.,"all")
        self.assertEqual(joints,[0,0,0,0])
        self.assertEqual(weights,[1.,0.,0.,0.])
        for fraction in (-.01,float("nan"),1.01):
            with self.assertRaises(RigError):
                redirect([0]*4,[1.,0.,0.,0.],["Head"],"Head",fraction)
        with self.assertRaises(RigError):
            redirect([1]*4,[1.,0.,0.,0.],["Head"],"Head",1.)

    def test_braid_domain_excludes_sleeve_and_includes_measured_tie_and_tip(self):
        region=REGIONS["NeutralArcherF"][0]
        self.assertEqual(region_amount(np.array([1.2,1.4,.3]),region),0.)
        for point in ([1.44069,1.94401,.01310],[1.54704,1.76032,.13805],[2.06521,1.71198,.32988]):
            self.assertEqual(region_amount(np.array(point),region),1.)

    def fixture(self):
        path=ROOT/"build/costume_r15/skin_candidates/weight_corrections/NeutralArcherF_v7/weight_plan.json"
        if not path.exists():
            self.skipTest("Actual original-braid review fixture is absent")
        return json.loads(path.read_text(encoding="utf-8"))

    def test_actual_reapplication_preserves_prefix_and_every_static_accessor(self):
        document=self.fixture()
        source=Path(document["source_skin"])
        before=source.read_bytes()
        old,binary,_=read_glb(source)
        with tempfile.TemporaryDirectory(prefix="weight_candidate_test_",dir=ROOT/"build") as directory:
            plan,output=Path(directory)/"plan.json",Path(directory)/"candidate.glb"
            plan.write_text(json.dumps(document),encoding="utf-8")
            report=apply(plan,output,True)
            new,new_binary,_=read_glb(output)
            self.assertEqual(new_binary[:len(binary)],binary)
            self.assertEqual(source.read_bytes(),before)
            self.assertFalse(report["original_source_weights_exact"])
            self.assertEqual(report["changed_skin_vertices"],794)
            for key in ("nodes","skins","materials","textures","images"):
                self.assertEqual(new[key],old[key])
            for mi,mesh in enumerate(old["meshes"]):
                for pi,primitive in enumerate(mesh["primitives"]):
                    actual=new["meshes"][mi]["primitives"][pi]
                    self.assertEqual(actual["indices"],primitive["indices"])
                    for attribute,index in primitive["attributes"].items():
                        if attribute not in ("JOINTS_0","WEIGHTS_0"):
                            self.assertEqual(actual["attributes"][attribute],index)
            for row in document["changes"]:
                p=new["meshes"][row["mesh"]]["primitives"][row["primitive"]]
                for attr,expected in (("JOINTS_0",row["new_joints"]),("WEIGHTS_0",row["new_weights"])):
                    self.assertEqual(list(accessor_values(new,new_binary,p["attributes"][attr])[row["vertex"]]),expected)
            with self.assertRaises(RigError):
                apply(plan,output,True)

    def test_unreviewed_stale_and_tampered_proposals_never_write_candidate(self):
        fixture=self.fixture()
        variants=[]
        unreviewed=copy.deepcopy(fixture);unreviewed["region_review_complete"]=False;variants.append(unreviewed)
        stale=copy.deepcopy(fixture);stale["source_skin_sha256"]="0"*64;variants.append(stale)
        target=copy.deepcopy(fixture);target["changes"][0]["target"]="LeftHand";variants.append(target)
        domain=copy.deepcopy(fixture);domain["changes"][0]["region"]="sleeve";variants.append(domain)
        count=copy.deepcopy(fixture);count["region_counts"]["posterior_right_braid"]-=1;variants.append(count)
        bone=copy.deepcopy(fixture);bone["bone_names"][0]="wrong";variants.append(bone)
        duplicate=copy.deepcopy(fixture);duplicate["changes"].append(duplicate["changes"][0]);variants.append(duplicate)
        with tempfile.TemporaryDirectory(prefix="weight_guard_test_",dir=ROOT/"build") as directory:
            for index,document in enumerate(variants):
                plan,output=Path(directory)/(str(index)+".json"),Path(directory)/(str(index)+".glb")
                plan.write_text(json.dumps(document),encoding="utf-8")
                with self.assertRaises(RigError):
                    apply(plan,output,True)
                self.assertFalse(output.exists())


if __name__=="__main__":
    unittest.main()
