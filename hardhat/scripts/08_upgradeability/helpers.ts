import fs from 'fs';
import path from 'path';

const DEPLOYMENT_FILE = path.join(__dirname, 'deployment.json');

export interface DeploymentData {
  proxyAddress: string;
  owner: string;
}

export function saveDeploymentData(data: DeploymentData): void {
  fs.writeFileSync(DEPLOYMENT_FILE, JSON.stringify(data, null, 2));
}

export function getDeploymentData(): DeploymentData {
  if (!fs.existsSync(DEPLOYMENT_FILE)) {
    throw new Error('deployment.json not found.');
  }

  const data = JSON.parse(fs.readFileSync(DEPLOYMENT_FILE, 'utf8'));

  if (!data.proxyAddress || !data.owner) {
    throw new Error('Missing required fields in deployment.json.');
  }

  return data;
}
