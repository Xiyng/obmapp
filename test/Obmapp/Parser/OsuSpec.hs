{-# LANGUAGE OverloadedStrings #-}

module Obmapp.Parser.OsuSpec where

import qualified Data.Map as M
import Test.Hspec
import Test.Hspec.Megaparsec
import Text.Megaparsec

import Utils
import qualified Obmapp.Beatmap as B
import Obmapp.Parser
import Obmapp.Parser.Osu

spec :: Spec
spec = do
    describe "versionInfo" $ do
        it "parses version 1" $ do
            parse versionInfo "" "osu file format v1" `shouldParse` B.FormatVersion 1
        it "parses a significantly newer version" $ do
            parse versionInfo "" "osu file format v13" `shouldParse` B.FormatVersion 13
        it "doesn't parse version 0" $ do
            parse versionInfo "" `shouldFailOn` "osu file format v0"
        it "doesn't parse a negative version" $ do
            parse versionInfo "" `shouldFailOn` "osu file format v-1"
    describe "section" $ do
        it "parses a section containing a single int" $ do
            parse (section "foo" int) "" "[foo]\r\n17" `shouldParse` 17
        it "parses a section containing trailing whitespace and a single int" $ do
            parse (section "foo" int) "" "[foo]\r\n17    \r\n    " `shouldParse` 17
        it "doesn't parse a section with no whitespace between the title and content" $ do
            parse (section "foo" int) "" `shouldFailOn` "[foo]17"
        it "parses a section containing leading whitespace and a single int" $ do
            parse (section "foo" int) "" `shouldFailOn` "    [foo]\r\n17"
    describe "sectionTitle" $ do
        it "parses a non-empty section title" $ do
            parse sectionTitle "" "[foobar]" `shouldParse` "foobar"
    describe "keyValuePair" $ do
        it "parses a key-text pair" $ do
            parse (keyValuePair "foo" textValue) "" "foo: bar" `shouldParse` "bar"
        it "parses a key-text pair followed by a newline and more text" $ do
            parse (keyValuePair "foo" textValue) "" "foo: b\r\nar" `shouldParse` "b"
        it "parses a key-int pair" $ do
            parse (keyValuePair "foo" int) "" "foo: 17" `shouldParse` 17
    describe "colourValues" $ do
        it "parses unique colour indices and colours" $ do
            parse colourValues "" "Combo1: 1,2,3\r\nCombo2: 4,5,6\r\n" `shouldParse` (M.fromList
                [ (1, (1, 2, 3))
                , (2, (4, 5, 6)) ] )
        it "doesn't parse colour values with duplicate indices" $ do
            parse colourValues "" `shouldFailOn` "Combo1: 1,2,3\r\nCombo1: 4,5,6\r\n"
    describe "colourValue"  $ do
        it "parses a valid colour value" $ do
            parse colourValue "" "Combo1 : 0,127,255" `shouldParse` (1, (0, 127, 255))
        it "parses a valid colour value with extra spacing" $ do
            parse colourValue "" "Combo3 : 12,24,36" `shouldParse` (3, (12, 24, 36))
    describe "colour" $ do
        it "parses a valid colour" $ do
            parse colour "" "1,2,3" `shouldParse` (1, 2, 3)
        it "parses pure black" $ do
            parse colour "" "0,0,0" `shouldParse` (0, 0, 0)
        it "parses pure white" $ do
            parse colour "" "255,255,255" `shouldParse` (255, 255, 255)
        it "doesn't parse a negative red value" $ do
            parse colour "" `shouldFailOn` "-1,2,3"
        it "doesn't parse a negative green value" $ do
            parse colour "" `shouldFailOn` "1,-2,3"
        it "doesn't parse a negative blue value" $ do
            parse colour "" `shouldFailOn` "1,2,-3"
        it "doesn't parse a red value greater than 255" $ do
            parse colour "" `shouldFailOn` "256,0,0"
    describe "hitObject" $ do
        it "parses a hit circle with extras" $ do
            parse hitObject "" "320,240,7500,1,1,0:0:0:0:" `shouldParse` B.HitObject
                { B.position = (320, 240)
                , B.time = 7500
                , B.newCombo = Nothing
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = True
                    , B.whistleHitSound = False
                    , B.finishHitSound  = False
                    , B.clapHitSound    = False }
                , B.details = B.HitCircle
                , B.extras = Just B.HitObjectExtras
                    { B.extrasSampleSet    = 0
                    , B.extrasAdditionSet  = 0
                    , B.extrasCustomIndex  = 0
                    , B.extrasSampleVolume = 0
                    , B.extrasFileName     = "" } }
        it "parses a hit circle without extras" $ do
            parse hitObject ""  "100,200,2500,1,1," `shouldParse` B.HitObject
                { B.position = (100, 200)
                , B.time     = 2500
                , B.newCombo = Nothing
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = True
                    , B.whistleHitSound = False
                    , B.finishHitSound  = False
                    , B.clapHitSound    = False }
                , B.details = B.HitCircle
                , B.extras   = Nothing }
        it "parses a bezier slider with missing repeat extras and without other extras" $ do
            parse hitObject "" "50,200,3000,2,2,B|32:192|32:384|480:384|480:160,3,560" `shouldParse` B.HitObject
                { B.position = (50, 200)
                , B.time     = 3000
                , B.newCombo = Nothing
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = False
                    , B.whistleHitSound = True
                    , B.finishHitSound  = False
                    , B.clapHitSound    = False }
                , B.details = B.Slider
                    { B.sliderShape = B.Bezier
                        [ [ ( 32, 192)
                            , ( 32, 384)
                            , (480, 384)
                            , (480, 160) ] ]
                    , B.edgeInfo    = B.EdgeInfo
                        { B.repeats = 3
                        , B.hitSoundsAndAdditions = [] } -- Well this is funny... Wasn't supposed to be able to be empty!
                    , B.pixelLength = 560 }
                , B.extras   = Nothing }
        it "parses a catmull slider with missing repeat extras and without other extras" $ do
            parse hitObject "" "40,150,5000,6,4,C|160:160|128:32|384:32|320:192,3,560" `shouldParse` B.HitObject
                { B.position = (40, 150)
                , B.time     = 5000
                , B.newCombo = Just 0
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = False
                    , B.whistleHitSound = False
                    , B.finishHitSound  = True
                    , B.clapHitSound    = False }
                , B.details = B.Slider
                    { B.sliderShape = B.Catmull
                        [ (160, 160)
                        , (128, 32 )
                        , (384, 32 )
                        , (320, 192) ]
                    , B.edgeInfo    = B.EdgeInfo
                        { B.repeats = 3
                        , B.hitSoundsAndAdditions = [] }
                    , B.pixelLength = 560 }
                , B.extras   = Nothing }
        it "parses a linear slider with missing repeat extras and without other extras" $ do
            parse hitObject "" "250,100,7000,2,8,L|320:96|162:95|160:322|352:320,1,560" `shouldParse` B.HitObject
                { B.position = (250, 100)
                , B.time     = 7000
                , B.newCombo = Nothing
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = False
                    , B.whistleHitSound = False
                    , B.finishHitSound  = False
                    , B.clapHitSound    = True }
                , B.details = B.Slider
                    { B.sliderShape = B.Linear
                        [ (320,  96)
                        , (162,  95)
                        , (160, 322)
                        , (352, 320) ]
                    , B.edgeInfo    = B.EdgeInfo
                        { B.repeats = 1
                        , B.hitSoundsAndAdditions = [] }
                    , B.pixelLength = 560 }
                , B.extras   = Nothing }
        it "parses a spinner without extras" $ do
            parse hitObject "" "300,50,9000,12,0,11000" `shouldParse` B.HitObject
                { B.position = (300, 50)
                , B.time     = 9000
                , B.newCombo = Just 0
                , B.hitSound = B.HitSound
                    { B.normalHitSound  = False
                    , B.whistleHitSound = False
                    , B.finishHitSound  = False
                    , B.clapHitSound    = False }
                , B.details = B.Spinner { B.endTime = 11000 }
                , B.extras  = Nothing }
    describe "hitObjectDetailsAndExtras" $ do
        it "parses hit circle details" $ do
            parse (hitObjectDetailsAndExtras HitCircle) "" "" `shouldParse` (B.HitCircle, Nothing)
        it "parses slider details" $ do
            parse (hitObjectDetailsAndExtras Slider) "" "L|320:240,1,12.5,1|2,0:0|1:2" `shouldParse` (B.Slider
                { B.sliderShape = B.Linear [(320, 240)]
                , B.edgeInfo = B.EdgeInfo
                    { B.repeats = 1
                    , B.hitSoundsAndAdditions =
                        [ (B.HitSound
                            { B.normalHitSound  = True
                            , B.whistleHitSound = False
                            , B.finishHitSound  = False
                            , B.clapHitSound    = False }
                          , B.SliderExtras
                            { B.sliderSampleSet   = 0
                            , B.sliderAdditionSet = 0 })
                        , (B.HitSound
                            { B.normalHitSound  = False
                            , B.whistleHitSound = True
                            , B.finishHitSound  = False
                            , B.clapHitSound    = False }
                          , B.SliderExtras
                            { B.sliderSampleSet   = 1
                            , B.sliderAdditionSet = 2 }) ] }
                , B.pixelLength = 12.5 }, Nothing)
        it "parses spinner details" $ do
            parse (hitObjectDetailsAndExtras Spinner) "" "10" `shouldParse` (B.Spinner { B.endTime = 10 }, Nothing)
    describe "hitObjectTypeDetails" $ do
        it "parses hit circle type" $ do
            parse hitObjectTypeDetails "" "1" `shouldParse` (HitCircle, Nothing)
        it "parses slider type" $ do
            parse hitObjectTypeDetails "" "2" `shouldParse` (Slider, Nothing)
        it "parses spinner type" $ do
            parse hitObjectTypeDetails "" "8" `shouldParse` (Spinner, Nothing)
        it "parses new combo with no combo colour skips" $ do
            parse hitObjectTypeDetails "" "6" `shouldParse` (Slider, Just 0)
        it "parses new combo with one combo colour skip" $ do
            parse hitObjectTypeDetails "" "22" `shouldParse` (Slider, Just 1)
        it "parses new combo with four combo colour skips" $ do
            parse hitObjectTypeDetails "" "70" `shouldParse` (Slider, Just 4)
        it "parses new combo with five combo colour skips" $ do
            parse hitObjectTypeDetails "" "86" `shouldParse` (Slider, Just 5)
    describe "hitSound" $ do
        it "parses a hit sound with no sounds set" $ do
            parse hitSound "" "0" `shouldParse` B.HitSound
                { B.normalHitSound  = False
                , B.whistleHitSound = False
                , B.finishHitSound  = False
                , B.clapHitSound    = False }
        it "parses a hit sound with just the normal hit sound set" $ do
            parse hitSound "" "1" `shouldParse` B.HitSound
                { B.normalHitSound  = True
                , B.whistleHitSound = False
                , B.finishHitSound  = False
                , B.clapHitSound    = False }
        it "parses a hit sound with just the normal hit sound set" $ do
            parse hitSound "" "2" `shouldParse` B.HitSound
                { B.normalHitSound  = False
                , B.whistleHitSound = True
                , B.finishHitSound  = False
                , B.clapHitSound    = False }
        it "parses a hit sound with just the normal hit sound set" $ do
            parse hitSound "" "4" `shouldParse` B.HitSound
                { B.normalHitSound  = False
                , B.whistleHitSound = False
                , B.finishHitSound  = True
                , B.clapHitSound    = False }
        it "parses a hit sound with just the normal hit sound set" $ do
            parse hitSound "" "8" `shouldParse` B.HitSound
                { B.normalHitSound  = False
                , B.whistleHitSound = False
                , B.finishHitSound  = False
                , B.clapHitSound    = True }
        it "parses a hit sound with two hit sounds set" $ do
            parse hitSound "" "10" `shouldParse` B.HitSound
                { B.normalHitSound  = False
                , B.whistleHitSound = True
                , B.finishHitSound  = False
                , B.clapHitSound    = True }
        it "parses a hit sound with all hit sounds set" $ do
            parse hitSound "" "15" `shouldParse` B.HitSound
                { B.normalHitSound  = True
                , B.whistleHitSound = True
                , B.finishHitSound  = True
                , B.clapHitSound    = True }
    describe "sliderShape" $ do
        it "parses a linear slider" $ do
            parse sliderShape "" "L|320:240" `shouldParse`
                (B.Linear [(320, 240)])
        it "parses a perfect slider" $ do
            parse sliderShape "" "P|320:240|120:80" `shouldParse`
                (B.Perfect (320, 240) (120, 80))
        it "parses a one-piece bezier slider" $ do
            parse sliderShape "" "B|320:240|120:80" `shouldParse`
                (B.Bezier [[(320, 240), (120, 80)]])
        it "parses a two-piece bezier slider" $ do
            parse sliderShape "" "B|320:240|120:80|120:80|240:200" `shouldParse`
                (B.Bezier [[(320, 240), (120, 80)], [(120, 80), (240, 200)]])
        it "parses a three-piece bezier slider" $ do
            parse sliderShape "" "B|320:240|120:80|120:80|240:200|240:200|170:150|80:140" `shouldParse`
                (B.Bezier
                    [ [(320, 240), (120, 80)]
                    , [(120, 80), (240, 200)]
                    , [(240, 200), (170, 150), (80, 140)] ])
        it "parses a catmull slider" $ do
            parse sliderShape "" "C|320:240|120:80" `shouldParse`
                (B.Catmull[ (320, 240), (120, 80)])
    describe "breakWhen" $ do
        it "doesn't break when the condition is not fulfilled" $ do
            breakWhen (==) [1..5] `shouldBe` [[1..5]]
        it "breaks once in a simple equality case" $ do
            breakWhen (==) [1,2,2,3] `shouldBe` [[1, 2], [2, 3]]
    describe "sliderType" $ do
        it "parses the linear slider type symbol" $ do
            parse sliderType "" "L" `shouldParse` Linear
        it "parses the perfect slider type symbol" $ do
            parse sliderType "" "P" `shouldParse` Perfect
        it "parses the bezier slider type symbol" $ do
            parse sliderType "" "B" `shouldParse` Bezier
        it "parses the catmull slider type symbol" $ do
            parse sliderType "" "C" `shouldParse` Catmull
        it "doesn't parse an invalid slider type" $ do
            parse sliderType "" `shouldFailOn` "A"
        it "doesn't parse a empty string" $ do
            parse sliderType "" `shouldFailOn` ""
