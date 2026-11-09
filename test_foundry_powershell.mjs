import OpenAI from 'openai';
import { AzurePowerShellCredential } from '@azure/identity';

const endpoint = 'https://gezamolnar2-4671-resource.services.ai.azure.com/openai/v1';
const deployment = 'gpt-5-mini';

try {
  const credential = new AzurePowerShellCredential();

  const client = new OpenAI({
    baseURL: endpoint,
    apiKey: async () => {
      const token = await credential.getToken('https://ai.azure.com/.default');
      return token.token;
    }
  });

  const response = await client.responses.create({
    model: deployment,
    input: 'Válaszolj magyarul: mennyi 2 + 2?',
    max_output_tokens: 200
  });

  console.log('Modell:', deployment);
  console.log('Válasz:', response.output_text || JSON.stringify(response.output));

} catch (error) {
  console.error('Foundry-hívás sikertelen:', error.status ?? '', error.message);
}
