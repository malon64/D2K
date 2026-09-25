"""Build the provisional D2K mechanical master layout in the active Fusion design.

Run via Fusion MCP Execute/script. Existing named components and bodies are reused.
This intentionally makes envelopes only; it does not make a printable enclosure.
"""

import adsk.core
import adsk.fusion


def run(_context: str):
    app = adsk.core.Application.get()
    design = adsk.fusion.Design.cast(app.activeProduct)
    if not design:
        raise RuntimeError("Open a Fusion design before building D2K Phase 1")
    if design.designType != adsk.fusion.DesignTypes.ParametricDesignType:
        raise RuntimeError("D2K Phase 1 requires a parametric design")

    params = design.userParameters
    values = {
        "case_width": ("165 mm", "Provisional review width after sweep; test 155, 160, 165 and 170 mm."),
        "case_depth": ("110 mm", "PROVISIONAL lower-half depth."),
        "lower_case_height": ("33 mm", "PROVISIONAL lower-half height to clear Pi 5 STEP and display."),
        "upper_case_height": ("12 mm", "PROVISIONAL upper-half height."),
        "wall_thickness": ("2.4 mm", "Provisional 3D printed wall."),
        "assembly_clearance": ("0.3 mm", "Provisional mating allowance; print-test."),
        "screen_clearance": ("1 mm", "Provisional screen perimeter allowance."),
        "hinge_outer_diameter": ("9 mm", "Provisional hinge barrel envelope."),
        "hinge_pin_diameter": ("3 mm", "Provisional metal hinge pin."),
        "control_clearance": ("2 mm", "Provisional planar control spacing."),
        "top_case_depth": ("94 mm", "PROVISIONAL upper-half depth."),
        "bottom_display_width": ("99 mm", "UNMEASURED 4-DSI-TOUCH-A module width."),
        "bottom_display_depth": ("65 mm", "UNMEASURED bottom display module depth."),
        "bottom_display_thickness": ("6 mm", "UNMEASURED bottom display stack."),
        "top_display_width": ("124 mm", "UNMEASURED 5-inch HDMI display module width."),
        "top_display_depth": ("77 mm", "UNMEASURED top display module depth."),
        "top_display_thickness": ("7 mm", "UNMEASURED top display stack."),
        "pi_width": ("89 mm", "Rounded overall X envelope from supplied Pi 5 STEP."),
        "pi_depth": ("58 mm", "Rounded overall Y envelope from supplied Pi 5 STEP."),
        "pi_stack_height": ("23 mm", "Pi 5 STEP Z keep-out from 1 to 24 mm; extra cooling remains TBD."),
        "battery_width": ("80 mm", "UNSELECTED battery placeholder width."),
        "battery_thickness": ("10 mm", "UNSELECTED battery placeholder thickness."),
        "circle_pad_diameter": ("26 mm", "UNMEASURED Circle Pad envelope."),
        "circle_pad_height": ("5 mm", "UNMEASURED Circle Pad top/travel envelope."),
        "dpad_width": ("25 mm", "UNMEASURED D-pad envelope."),
        "dpad_depth": ("25 mm", "UNMEASURED D-pad envelope."),
        "upper_screen_center_y": ("case_depth/2 + top_case_depth/2", "Upper flat-layout center."),
        "bottom_screen_center_y": ("-2 mm", "Bottom display row; tune after mock-up."),
        "circle_pad_y": ("-20 mm", "Circle Pad row; tune after mock-up."),
        "button_row_y": ("19 mm", "D-pad and ABXY row; tune after mock-up."),
        "shoulder_outer_x": ("case_width/2 - 17 mm", "Shoulder center follows width."),
        "shoulder_rear_y": ("case_depth/2 - 3 mm", "L1/R1 row near rear edge."),
        "shoulder_inner_y": ("case_depth/2 - 16 mm", "L2/R2 row below L1/R1."),
        "shoulder_width": ("25 mm", "Provisional shallow shoulder mechanism width."),
        "shoulder_depth": ("9 mm", "Provisional shallow shoulder mechanism depth."),
        "shoulder_height": ("7 mm", "Provisional shoulder mechanism height."),
        "hinge_axis_y": ("case_depth/2 + 2 mm", "Rear hinge axis in flat layout."),
        "hinge_axis_z": ("lower_case_height - 4 mm", "Provisional hinge-axis height."),
        "hdmi_passage_width": ("14 mm", "PROVISIONAL HDMI-compatible flex passage."),
        "audio_passage_width": ("9 mm", "PROVISIONAL display power and speaker-wire passage."),
        "cable_passage_depth": ("24 mm", "PROVISIONAL passage length across hinge."),
        "cable_bend_radius": ("10 mm", "PROVISIONAL loop radius; verify flex cable data."),
        "control_center_x": (
            "(case_width/2 + bottom_display_width/2 + control_clearance - wall_thickness)/2",
            "Balances pad-to-display clearance against outer wall at each width.",
        ),
        "abxy_width": ("25 mm", "UNMEASURED compact ABXY cluster envelope."),
        "abxy_depth": ("25 mm", "UNMEASURED compact ABXY cluster envelope."),
        "battery_depth": ("41 mm", "UNSELECTED battery placeholder depth."),
        "cable_port_x": ("38 mm", "Cable passage center magnitude; clear of shoulders."),
        "hinge_barrel_width": ("54 mm", "Central hinge barrel leaves cable loops clear."),
        "pi_center_y": ("20 mm", "Pi placement in lower half; adjust after connector measurement."),
        "battery_center_y": ("-31 mm", "Battery placement near front of lower half."),
        "esp_width": ("25.4 mm", "Board X size from supplied DevKitC-1 PADS outline; no connector margin."),
        "esp_depth": ("63 mm", "Rounded board Y size from supplied 62.865 mm PADS outline."),
        "esp_height": ("8 mm", "PROVISIONAL ESP32-S3 board and connector stack."),
        "esp_center_y": ("0 mm", "Long DevKitC-1 placed lengthwise in left side strip."),
        "amp_width": ("28 mm", "UNSELECTED audio amplifier envelope."),
        "amp_depth": ("18 mm", "UNSELECTED audio amplifier envelope."),
        "amp_height": ("5 mm", "UNSELECTED audio amplifier stack."),
        "amp_center_y": ("-38 mm", "Amplifier placeholder position."),
        "speaker_width": ("12 mm", "UNSELECTED small top speaker width."),
        "speaker_depth": ("24 mm", "UNSELECTED small top speaker depth."),
        "speaker_height": ("4 mm", "UNSELECTED small top speaker depth envelope."),
        "face_button_width": ("7 mm", "UNMEASURED Start/Select/Home placeholder."),
        "face_button_center_y": ("-44 mm", "Front button row, tunable for hand mock-up."),
        "closed_lid_inner_z": (
            "lower_case_height + circle_pad_height + screen_clearance",
            "Minimum provisional lid inner surface when closed; 33 mm initially.",
        ),
    }
    for name, (expression, comment) in values.items():
        item = params.itemByName(name)
        if item:
            item.expression = expression
            item.comment = comment
        elif not params.add(name, adsk.core.ValueInput.createByString(expression), "mm", comment):
            raise RuntimeError("Could not add parameter " + name)

    def component(parent, name):
        for i in range(parent.occurrences.count):
            found = parent.occurrences.item(i).component
            if found.name == name:
                return found
        made = parent.occurrences.addNewComponent(adsk.core.Matrix3D.create()).component
        made.name = name
        return made

    def cm(expression):
        return design.fusionUnitsManager.evaluateExpression(expression, "mm")

    def new_sketch_at_z(comp, title, z_expression):
        if abs(cm(z_expression)) < 1e-7:
            plane = comp.xYConstructionPlane
        else:
            plane_input = comp.constructionPlanes.createInput()
            if not plane_input.setByOffset(
                comp.xYConstructionPlane,
                adsk.core.ValueInput.createByString(z_expression),
            ):
                raise RuntimeError("Cannot set offset plane for " + title)
            plane = comp.constructionPlanes.add(plane_input)
            plane.name = title + " Z datum"
        sketch = comp.sketches.add(plane)
        sketch.name = title + " plan"
        return sketch

    def dimension(sketch, a, b, orientation, text_x, text_y, expression):
        item = sketch.sketchDimensions.addDistanceDimension(
            a, b, orientation, adsk.core.Point3D.create(text_x, text_y, 0)
        )
        if not item:
            raise RuntimeError("Cannot dimension " + sketch.name)
        item.parameter.expression = expression

    def box(group, name, x_expr, y_expr, width_expr, depth_expr,
            z_expr, height_expr, x_anchor, y_anchor, opacity=0.45):
        comp = component(group, name)
        if comp.bRepBodies.count:
            return comp
        x, y = cm(x_expr), cm(y_expr)
        width, depth = cm(width_expr), cm(depth_expr)
        sketch = new_sketch_at_z(comp, name, z_expr)
        lines = sketch.sketchCurves.sketchLines.addTwoPointRectangle(
            adsk.core.Point3D.create(x, y, 0),
            adsk.core.Point3D.create(x + width, y + depth, 0),
        )
        bottom = left = bottom_left = None
        for i in range(lines.count):
            line = lines.item(i)
            a, b = line.startSketchPoint.geometry, line.endSketchPoint.geometry
            if abs(a.y - y) < 1e-5 and abs(b.y - y) < 1e-5:
                bottom = line
            if abs(a.x - x) < 1e-5 and abs(b.x - x) < 1e-5:
                left = line
        if not bottom or not left:
            raise RuntimeError("Could not identify rectangle edges for " + name)
        for point in (bottom.startSketchPoint, bottom.endSketchPoint):
            if abs(point.geometry.x - x) < 1e-5:
                bottom_left = point
        hor = adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation
        ver = adsk.fusion.DimensionOrientations.VerticalDimensionOrientation
        dimension(sketch, bottom.startSketchPoint, bottom.endSketchPoint,
                  hor, x + width / 2, y - 0.5, width_expr)
        dimension(sketch, left.startSketchPoint, left.endSketchPoint,
                  ver, x - 0.5, y + depth / 2, depth_expr)
        dimension(sketch, sketch.originPoint, bottom_left,
                  hor, x / 2, y - 0.5, x_anchor)
        dimension(sketch, sketch.originPoint, bottom_left,
                  ver, x - 0.5, y / 2, y_anchor)
        feature = comp.features.extrudeFeatures.addSimple(
            sketch.profiles.item(0),
            adsk.core.ValueInput.createByString(height_expr),
            adsk.fusion.FeatureOperations.NewBodyFeatureOperation,
        )
        feature.name = name + " envelope"
        feature.bodies.item(0).name = name + " provisional volume"
        feature.bodies.item(0).opacity = opacity
        return comp

    def disk(group, name, x_expr, y_expr, diameter_expr,
             z_expr, height_expr, x_anchor, y_anchor, opacity=0.45):
        comp = component(group, name)
        if comp.bRepBodies.count:
            return comp
        x, y = cm(x_expr), cm(y_expr)
        sketch = new_sketch_at_z(comp, name, z_expr)
        circle = sketch.sketchCurves.sketchCircles.addByCenterRadius(
            adsk.core.Point3D.create(x, y, 0), cm(diameter_expr) / 2
        )
        diameter = sketch.sketchDimensions.addDiameterDimension(
            circle, adsk.core.Point3D.create(x + 1.6, y + 1.6, 0)
        )
        diameter.parameter.expression = diameter_expr
        hor = adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation
        ver = adsk.fusion.DimensionOrientations.VerticalDimensionOrientation
        dimension(sketch, sketch.originPoint, circle.centerSketchPoint,
                  hor, x / 2, y - 0.5, x_anchor)
        dimension(sketch, sketch.originPoint, circle.centerSketchPoint,
                  ver, x - 0.5, y / 2, y_anchor)
        feature = comp.features.extrudeFeatures.addSimple(
            sketch.profiles.item(0),
            adsk.core.ValueInput.createByString(height_expr),
            adsk.fusion.FeatureOperations.NewBodyFeatureOperation,
        )
        feature.name = name + " envelope"
        feature.bodies.item(0).name = name + " provisional volume"
        feature.bodies.item(0).opacity = opacity
        return comp

    master = component(design.rootComponent, "D2K_MASTER")
    reference = component(master, "00_REFERENCE")
    for name in ("AYN_Thor", "Nintendo_DS", "R36S"):
        component(reference, name)
    electronics = component(master, "01_ELECTRONICS")
    controls = component(master, "02_CONTROLS")
    enclosure = component(master, "03_D2K_CASE")

    box(enclosure, "Lower", "-case_width/2", "-case_depth/2",
        "case_width", "case_depth", "0 mm", "1 mm",
        "case_width/2", "case_depth/2", 0.18)
    box(electronics, "Waveshare_4_DSI", "-bottom_display_width/2",
        "bottom_screen_center_y-bottom_display_depth/2",
        "bottom_display_width", "bottom_display_depth",
        "lower_case_height-bottom_display_thickness", "bottom_display_thickness",
        "bottom_display_width/2", "bottom_display_depth/2-bottom_screen_center_y", 0.55)
    box(enclosure, "Upper", "-case_width/2", "case_depth/2",
        "case_width", "top_case_depth", "0 mm", "1 mm",
        "case_width/2", "case_depth/2", 0.18)
    box(electronics, "Waveshare_5in_HDMI", "-top_display_width/2",
        "upper_screen_center_y-top_display_depth/2",
        "top_display_width", "top_display_depth",
        "upper_case_height-top_display_thickness", "top_display_thickness",
        "top_display_width/2", "upper_screen_center_y-top_display_depth/2", 0.55)
    box(electronics, "Raspberry_Pi_5.step", "-pi_width/2", "pi_center_y-pi_depth/2",
        "pi_width", "pi_depth", "1 mm", "pi_stack_height",
        "pi_width/2", "pi_depth/2-pi_center_y", 0.55)
    box(electronics, "Battery", "-battery_width/2",
        "battery_center_y-battery_depth/2", "battery_width", "battery_depth",
        "3 mm", "battery_thickness", "battery_width/2",
        "battery_depth/2-battery_center_y", 0.55)
    box(electronics, "ESP32_S3", "-case_width/2+wall_thickness+2 mm",
        "esp_center_y-esp_depth/2", "esp_width", "esp_depth", "3 mm", "esp_height",
        "case_width/2-wall_thickness-2 mm", "esp_depth/2-esp_center_y", 0.55)
    box(electronics, "Audio_Amp", "battery_width/2+4 mm",
        "amp_center_y-amp_depth/2", "amp_width", "amp_depth", "3 mm", "amp_height",
        "battery_width/2+4 mm", "amp_depth/2-amp_center_y", 0.55)
    speakers = component(electronics, "Speakers")
    box(speakers, "Speaker_L", "-case_width/2+wall_thickness+2 mm",
        "upper_screen_center_y-speaker_depth/2", "speaker_width", "speaker_depth",
        "5 mm", "speaker_height", "case_width/2-wall_thickness-2 mm",
        "upper_screen_center_y-speaker_depth/2", 0.55)
    box(speakers, "Speaker_R", "case_width/2-wall_thickness-2 mm-speaker_width",
        "upper_screen_center_y-speaker_depth/2", "speaker_width", "speaker_depth",
        "5 mm", "speaker_height", "case_width/2-wall_thickness-2 mm-speaker_width",
        "upper_screen_center_y-speaker_depth/2", 0.55)

    for side in ("L", "R"):
        x = "-control_center_x" if side == "L" else "control_center_x"
        disk(controls, "CirclePad_" + side, x, "circle_pad_y",
             "circle_pad_diameter", "lower_case_height", "circle_pad_height",
             "control_center_x", "-circle_pad_y", 0.70)
    box(controls, "DPad", "-control_center_x-dpad_width/2",
        "button_row_y-dpad_depth/2", "dpad_width", "dpad_depth",
        "lower_case_height", "3 mm", "control_center_x+dpad_width/2",
        "button_row_y-dpad_depth/2", 0.7)
    box(controls, "ABXY", "control_center_x-abxy_width/2",
        "button_row_y-abxy_depth/2", "abxy_width", "abxy_depth",
        "lower_case_height", "3 mm", "control_center_x-abxy_width/2",
        "button_row_y-abxy_depth/2", 0.7)
    front = component(controls, "Start_Select_Home")
    for name, x_expr, x_anchor in (
        ("Start", "-15 mm-face_button_width/2", "15 mm+face_button_width/2"),
        ("Select", "-face_button_width/2", "face_button_width/2"),
        ("Home", "15 mm-face_button_width/2", "15 mm-face_button_width/2"),
    ):
        box(front, name, x_expr, "face_button_center_y-face_button_width/2",
            "face_button_width", "face_button_width", "lower_case_height", "3 mm",
            x_anchor, "face_button_width/2-face_button_center_y", 0.7)

    for side in ("L", "R"):
        shoulder = component(controls, side + "1_" + side + "2")
        if side == "L":
            x_expr = "-shoulder_outer_x-shoulder_width/2"
            x_anchor = "shoulder_outer_x+shoulder_width/2"
        else:
            x_expr = "shoulder_outer_x-shoulder_width/2"
            x_anchor = x_expr
        for level, y_center in (("1", "shoulder_rear_y"), ("2", "shoulder_inner_y")):
            box(shoulder, side + level, x_expr, y_center + "-shoulder_depth/2",
                "shoulder_width", "shoulder_depth",
                "lower_case_height-shoulder_height", "shoulder_height",
                x_anchor, y_center + "-shoulder_depth/2", 0.30)

    hinge = box(enclosure, "Hinge", "-hinge_barrel_width/2",
        "hinge_axis_y-hinge_outer_diameter/2",
        "hinge_barrel_width", "hinge_outer_diameter",
        "hinge_axis_z-hinge_outer_diameter/2", "hinge_outer_diameter",
        "hinge_barrel_width/2", "hinge_axis_y-hinge_outer_diameter/2", 0.25)
    if hinge.sketches.count == 1:
        axis = hinge.sketches.add(hinge.xYConstructionPlane)
        axis.name = "Hinge axis schematic — X direction at rear"
        axis.is3D = True
        axis_line = axis.sketchCurves.sketchLines.addByTwoPoints(
            adsk.core.Point3D.create(-cm("hinge_barrel_width")/2,
                                     cm("hinge_axis_y"), cm("hinge_axis_z")),
            adsk.core.Point3D.create(cm("hinge_barrel_width")/2,
                                     cm("hinge_axis_y"), cm("hinge_axis_z")),
        )
        axis_line.isConstruction = True

    box(hinge, "HDMI_Hinge_Path", "-cable_port_x-hdmi_passage_width/2",
        "hinge_axis_y-cable_passage_depth/2", "hdmi_passage_width",
        "cable_passage_depth", "hinge_axis_z-3 mm", "8 mm",
        "cable_port_x+hdmi_passage_width/2",
        "hinge_axis_y-cable_passage_depth/2", 0.22)
    box(hinge, "Power_Audio_Hinge_Path", "cable_port_x-audio_passage_width/2",
        "hinge_axis_y-cable_passage_depth/2", "audio_passage_width",
        "cable_passage_depth", "hinge_axis_z-3 mm", "8 mm",
        "cable_port_x-audio_passage_width/2",
        "hinge_axis_y-cable_passage_depth/2", 0.22)
    loops = component(hinge, "Cable_Service_Loops")
    for side in ("HDMI_L", "Power_Audio_R"):
        x = "-cable_port_x" if side == "HDMI_L" else "cable_port_x"
        disk(loops, side, x, "hinge_axis_y-12 mm",
             "2*cable_bend_radius", "hinge_axis_z-3 mm", "8 mm",
             "cable_port_x", "hinge_axis_y-12 mm", 0.22)

    app.activeViewport.fit()
    print("D2K Phase 1 envelopes built; parameters", params.count,
          "timeline", design.timeline.count)
