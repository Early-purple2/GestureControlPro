// gesture_handler.js
// Module de traitement des commandes gestuelles

const { exec } = require('child_process');

/**
 * Exécute une commande gestuelle reçue.
 * @param {Object} command - Payload de commande { action, position, metadata }
 * @returns {Promise<boolean>} - true si réussite, false sinon
 */
async function handleGestureCommand(command) {
  return new Promise((resolve) => {
    // Exemple : exécuter un script Python pour la commande
    const payload = JSON.stringify(command);
    const cmd = `python3 gesture_executor.py '${payload}'`;

    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        console.error('❌ Erreur gesture_executor:', stderr);
        return resolve(false);
      }
      console.log('✅ Commande exécutée:', stdout.trim());
      resolve(true);
    });
  });
}

module.exports = { handleGestureCommand };

