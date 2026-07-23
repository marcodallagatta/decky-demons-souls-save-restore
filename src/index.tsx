import {
  ButtonItem,
  ConfirmModal,
  PanelSection,
  PanelSectionRow,
  showModal,
} from "@decky/ui";
import { callable, definePlugin, toaster } from "@decky/api";
import { useState } from "react";
import { FaSave } from "react-icons/fa";

type ActionResult = {
  ok: boolean;
  message: string;
  timestamp?: string;
};

const createCheckpoint = callable<[], ActionResult>("create_checkpoint");
const restoreCheckpoint = callable<[], ActionResult>("restore_checkpoint");

function Content() {
  const [running, setRunning] = useState(false);

  const runAction = async (
    action: () => Promise<ActionResult>,
  ) => {
    setRunning(true);
    try {
      const result = await action();
      toaster.toast({
        title: "Demon's Souls Checkpoints",
        body: result.message,
      });
    } catch {
      const message = "Checkpoint action could not start; no save was changed";
      toaster.toast({
        title: "Demon's Souls Checkpoints",
        body: message,
      });
    } finally {
      setRunning(false);
    }
  };

  const showCreateConfirmation = () => {
    let modal = showModal(
      <ConfirmModal
        strTitle="Create boss checkpoint?"
        strDescription="Only continue after using Quit Game in Demon's Souls and reaching its title screen."
        strOKButtonText="Create checkpoint"
        strCancelButtonText="Cancel"
        onOK={() => {
          modal.Close();
          void runAction(createCheckpoint);
        }}
      />,
    );
  };

  const showRestoreConfirmation = () => {
    let modal = showModal(
      <ConfirmModal
        bDestructiveWarning
        strTitle="Restore latest boss checkpoint?"
        strDescription="Only continue after using Quit Game in Demon's Souls and reaching its title screen. The current post-death save will be preserved before the checkpoint is restored."
        strOKButtonText="Restore checkpoint"
        strCancelButtonText="Cancel"
        onOK={() => {
          modal.Close();
          void runAction(restoreCheckpoint);
        }}
      />,
    );
  };

  return (
    <PanelSection title="Demon's Souls">
      <PanelSectionRow>
        <ButtonItem
          layout="below"
          disabled={running}
          onClick={showCreateConfirmation}
        >
          Create boss checkpoint
        </ButtonItem>
      </PanelSectionRow>
      <PanelSectionRow>
        <ButtonItem
          layout="below"
          disabled={running}
          onClick={showRestoreConfirmation}
        >
          Restore latest boss checkpoint
        </ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
}

export default definePlugin(() => ({
  name: "DeS Checkpoints",
  content: <Content />,
  icon: <FaSave />,
}));
