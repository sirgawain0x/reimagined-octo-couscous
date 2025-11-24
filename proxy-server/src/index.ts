import express, { Request, Response } from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'ok' });
});

interface AmazonReportRequest {
  date?: string;
}

/**
 * Endpoint: /amazon-reports
 * Description: Fetches sales reports from Amazon (or mocks them for now)
 * Usage: GET /amazon-reports?date=today
 */
app.get('/amazon-reports', async (req: Request<{}, {}, {}, AmazonReportRequest>, res: Response) => {
  try {
    const { date } = req.query;
    console.log(`Received request for amazon reports. Date: ${date}`);

    // TODO: INTEGRATE REAL AMAZON REPORTING HERE
    // Real integration requires access to Amazon Associates Reports, which often involves:
    // 1. Using a headless browser to download reports (Puppeteer/Selenium)
    // 2. Using an authorized third-party aggregator API
    // 3. (Rare) Access to a specific reporting API if available to your tier
    
    // For the "Shop-to-Earn" blueprint, we are simulating the response 
    // that the Motoko canister expects.
    
    // MOCK DATA RESPONSE
    // This simulates finding a purchase made by a user with Principal ID "2vxsx-fae..."
    const mockReportResponse = {
      status: "success",
      date: date || new Date().toISOString().split('T')[0],
      sales: [
        {
          orderId: "114-1234567-1234567",
          subtag: "2vxsx-fae-123-456", // This matches the format the Motoko canister looks for
          commission: 5.00,
          currency: "USD",
          items: [
            {
              asin: "B08F6BPH4C",
              title: "Example Product Blender",
              price: 100.00
            }
          ]
        }
      ]
    };

    // The Motoko canister currently does simple parsing:
    // let userPrincipal = extractField(jsonString, "subtag");
    // So we ensure "subtag" is present in the JSON string.
    
    // In production, you might return just the list of subtags and amounts
    res.json(mockReportResponse);

  } catch (error) {
    console.error('Error processing amazon report request:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

app.listen(port, () => {
  console.log(`Proxy server running on port ${port}`);
});

