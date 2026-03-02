import { Composition } from "remotion";
import { TrainerPromo } from "./TrainerPromo";
import { KirovPreview } from "./KirovPreview";
import { ScFirebatPreview } from "./ScFirebatPreview";
import { ScMedicPreview } from "./ScMedicPreview";
import { ScScvPreview } from "./ScScvPreview";
import { ArnoldPreview } from "./ArnoldPreview";
import { CcgUsDozerPreview } from "./CcgUsDozerPreview";
import { CcgGlaWorkerPreview } from "./CcgGlaWorkerPreview";
import { Wc2HumanShipsPreview } from "./Wc2HumanShipsPreview";
import { Wc2SapperPreview } from "./Wc2SapperPreview";
import { JarvisPreview } from "./JarvisPreview";
import { Hal9000Preview } from "./Hal9000Preview";
import { SiliconValleyPreview } from "./SiliconValleyPreview";
import { WolfETPreview } from "./WolfETPreview";
import { MeeseeksPreview } from "./MeeseeksPreview";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="TrainerPromo"
        component={TrainerPromo}
        durationInFrames={1400}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="KirovPreview"
        component={KirovPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="ScFirebatPreview"
        component={ScFirebatPreview}
        durationInFrames={900}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="ScMedicPreview"
        component={ScMedicPreview}
        durationInFrames={1010}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="ScScvPreview"
        component={ScScvPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="ArnoldPreview"
        component={ArnoldPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="CcgUsDozerPreview"
        component={CcgUsDozerPreview}
        durationInFrames={940}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="CcgGlaWorkerPreview"
        component={CcgGlaWorkerPreview}
        durationInFrames={975}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="Wc2HumanShipsPreview"
        component={Wc2HumanShipsPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="Wc2SapperPreview"
        component={Wc2SapperPreview}
        durationInFrames={840}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="WolfETPreview"
        component={WolfETPreview}
        durationInFrames={910}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="SiliconValleyPreview"
        component={SiliconValleyPreview}
        durationInFrames={894}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="Hal9000Preview"
        component={Hal9000Preview}
        durationInFrames={1223}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="JarvisPreview"
        component={JarvisPreview}
        durationInFrames={1169}
        fps={30}
        width={1080}
        height={1080}
      />
      <Composition
        id="MeeseeksPreview"
        component={MeeseeksPreview}
        durationInFrames={1110}
        fps={30}
        width={1080}
        height={1080}
      />
    </>
  );
};
