/**
 * This file was auto-generated by openapi-typescript.
 * Do not make direct changes to the file.
 */

export interface paths {
  "/v1/bids": {
    /**
     * Bid on a specific permission key for a specific chain.
     * @description Bid on a specific permission key for a specific chain.
     *
     * Your bid will be simulated and verified by the server. Depending on the outcome of the auction, a transaction
     * containing the contract call will be sent to the blockchain expecting the bid amount to be paid after the call.
     */
    post: operations["bid"];
  };
  "/v1/bids/{bid_id}": {
    /**
     * Query the status of a specific bid.
     * @description Query the status of a specific bid.
     */
    get: operations["bid_status"];
  };
  "/v1/opportunities": {
    /**
     * Fetch all opportunities ready to be exectued.
     * @description Fetch all opportunities ready to be exectued.
     */
    get: operations["get_opportunities"];
    /**
     * Submit an opportunity ready to be executed.
     * @description Submit an opportunity ready to be executed.
     *
     * The opportunity will be verified by the server. If the opportunity is valid, it will be stored in the database
     * and will be available for bidding.
     */
    post: operations["post_opportunity"];
  };
  "/v1/opportunities/{opportunity_id}/bids": {
    /**
     * Bid on opportunity
     * @description Bid on opportunity
     */
    post: operations["opportunity_bid"];
  };
}

export type webhooks = Record<string, never>;

export interface components {
  schemas: {
    APIResponse: components["schemas"]["BidResult"];
    Bid: {
      /**
       * @description Amount of bid in wei.
       * @example 10
       */
      amount: string;
      /**
       * @description The chain id to bid on.
       * @example op_sepolia
       */
      chain_id: string;
      /**
       * @description The permission key to bid on.
       * @example 0xdeadbeef
       */
      permission_key: string;
      /**
       * @description Calldata for the contract call.
       * @example 0xdeadbeef
       */
      target_calldata: string;
      /**
       * @description The contract address to call.
       * @example 0xcA11bde05977b3631167028862bE2a173976CA11
       */
      target_contract: string;
    };
    BidResult: {
      /**
       * @description The unique id created to identify the bid. This id can be used to query the status of the bid.
       * @example beedbeed-58cc-4372-a567-0e02b2c3d479
       */
      id: string;
      status: string;
    };
    BidStatus:
      | {
          /** @enum {string} */
          type: "pending";
        }
      | {
          /** @enum {string} */
          type: "simulation_failed";
        }
      | {
          /**
           * Format: int32
           * @example 1
           */
          index: number;
          /** @example 0x103d4fbd777a36311b5161f2062490f761f25b67406badb2bace62bb170aa4e3 */
          result: string;
          /** @enum {string} */
          type: "submitted";
        }
      | {
          /** @example 0x103d4fbd777a36311b5161f2062490f761f25b67406badb2bace62bb170aa4e3 */
          result: string;
          /** @enum {string} */
          type: "lost";
        };
    BidStatusWithId: {
      bid_status: components["schemas"]["BidStatus"];
      id: string;
    };
    ClientMessage:
      | {
          /** @enum {string} */
          method: "subscribe";
          params: {
            chain_ids: string[];
          };
        }
      | {
          /** @enum {string} */
          method: "unsubscribe";
          params: {
            chain_ids: string[];
          };
        }
      | {
          /** @enum {string} */
          method: "post_bid";
          params: {
            bid: components["schemas"]["Bid"];
          };
        }
      | {
          /** @enum {string} */
          method: "post_opportunity_bid";
          params: {
            opportunity_bid: components["schemas"]["OpportunityBid"];
            opportunity_id: string;
          };
        };
    ClientRequest: components["schemas"]["ClientMessage"] & {
      id: string;
    };
    EIP712Domain: {
      /**
       * @description The network chain id parameter for EIP712 domain.
       * @example 31337
       */
      chain_id: string;
      /**
       * @description The name parameter for the EIP712 domain.
       * @example OpportunityAdapter
       */
      name: string;
      /**
       * @description The verifying contract address parameter for the EIP712 domain.
       * @example 0xcA11bde05977b3631167028862bE2a173976CA11
       */
      verifying_contract: string;
      /**
       * @description The version parameter for the EIP712 domain.
       * @example 1
       */
      version: string;
    };
    ErrorBodyResponse: {
      error: string;
    };
    OpportunityBid: {
      /**
       * @description The bid amount in wei.
       * @example 1000000000000000000
       */
      amount: string;
      /**
       * @description Executor address
       * @example 0x5FbDB2315678afecb367f032d93F642f64180aa2
       */
      executor: string;
      /**
       * @description The opportunity permission key
       * @example 0xdeadbeefcafe
       */
      permission_key: string;
      /** @example 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12 */
      signature: string;
      /**
       * @description The latest unix timestamp in seconds until which the bid is valid
       * @example 1000000000000000000
       */
      valid_until: string;
    };
    OpportunityParams: components["schemas"]["OpportunityParamsV1"] & {
      /** @enum {string} */
      version: "v1";
    };
    /**
     * @description Opportunity parameters needed for on-chain execution
     * If a searcher signs the opportunity and have approved enough tokens to opportunity adapter,
     * by calling this target contract with the given target calldata and structures, they will
     * send the tokens specified in the sell_tokens field and receive the tokens specified in the buy_tokens field.
     */
    OpportunityParamsV1: {
      buy_tokens: components["schemas"]["TokenAmount"][];
      /**
       * @description The chain id where the opportunity will be executed.
       * @example op_sepolia
       */
      chain_id: string;
      /**
       * @description The permission key required for successful execution of the opportunity.
       * @example 0xdeadbeefcafe
       */
      permission_key: string;
      sell_tokens: components["schemas"]["TokenAmount"][];
      /**
       * @description The value to send with the contract call.
       * @example 1
       */
      target_call_value: string;
      /**
       * @description Calldata for the target contract call.
       * @example 0xdeadbeef
       */
      target_calldata: string;
      /**
       * @description The contract address to call for execution of the opportunity.
       * @example 0xcA11bde05977b3631167028862bE2a173976CA11
       */
      target_contract: string;
    };
    /** @description Similar to OpportunityParams, but with the opportunity id included. */
    OpportunityParamsWithMetadata: (components["schemas"]["OpportunityParamsV1"] & {
      /** @enum {string} */
      version: "v1";
    }) & {
      /**
       * @description Creation time of the opportunity (in microseconds since the Unix epoch)
       * @example 1700000000000000
       */
      creation_time: number;
      eip_712_domain: components["schemas"]["EIP712Domain"];
      /**
       * @description The opportunity unique id
       * @example obo3ee3e-58cc-4372-a567-0e02b2c3d479
       */
      opportunity_id: string;
    };
    ServerResultMessage:
      | {
          result: components["schemas"]["APIResponse"] | null;
          /** @enum {string} */
          status: "success";
        }
      | {
          result: string;
          /** @enum {string} */
          status: "error";
        };
    /**
     * @description This enum is used to send the result for a specific client request with the same id
     * id is only None when the client message is invalid
     */
    ServerResultResponse: components["schemas"]["ServerResultMessage"] & {
      id?: string | null;
    };
    /** @description This enum is used to send an update to the client for any subscriptions made */
    ServerUpdateResponse:
      | {
          opportunity: components["schemas"]["OpportunityParamsWithMetadata"];
          /** @enum {string} */
          type: "new_opportunity";
        }
      | {
          status: components["schemas"]["BidStatusWithId"];
          /** @enum {string} */
          type: "bid_status_update";
        };
    TokenAmount: {
      /**
       * @description Token amount
       * @example 1000
       */
      amount: string;
      /**
       * @description Token contract address
       * @example 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
       */
      token: string;
    };
  };
  responses: {
    BidResult: {
      content: {
        "application/json": {
          /**
           * @description The unique id created to identify the bid. This id can be used to query the status of the bid.
           * @example beedbeed-58cc-4372-a567-0e02b2c3d479
           */
          id: string;
          status: string;
        };
      };
    };
    /** @description An error occurred processing the request */
    ErrorBodyResponse: {
      content: {
        "application/json": {
          error: string;
        };
      };
    };
    /** @description Similar to OpportunityParams, but with the opportunity id included. */
    OpportunityParamsWithMetadata: {
      content: {
        "application/json": (components["schemas"]["OpportunityParamsV1"] & {
          /** @enum {string} */
          version: "v1";
        }) & {
          /**
           * @description Creation time of the opportunity (in microseconds since the Unix epoch)
           * @example 1700000000000000
           */
          creation_time: number;
          eip_712_domain: components["schemas"]["EIP712Domain"];
          /**
           * @description The opportunity unique id
           * @example obo3ee3e-58cc-4372-a567-0e02b2c3d479
           */
          opportunity_id: string;
        };
      };
    };
  };
  parameters: never;
  requestBodies: never;
  headers: never;
  pathItems: never;
}

export type $defs = Record<string, never>;

export type external = Record<string, never>;

export interface operations {
  /**
   * Bid on a specific permission key for a specific chain.
   * @description Bid on a specific permission key for a specific chain.
   *
   * Your bid will be simulated and verified by the server. Depending on the outcome of the auction, a transaction
   * containing the contract call will be sent to the blockchain expecting the bid amount to be paid after the call.
   */
  bid: {
    requestBody: {
      content: {
        "application/json": components["schemas"]["Bid"];
      };
    };
    responses: {
      /** @description Bid was placed successfully */
      200: {
        content: {
          "application/json": components["schemas"]["BidResult"];
        };
      };
      400: components["responses"]["ErrorBodyResponse"];
      /** @description Chain id was not found */
      404: {
        content: {
          "application/json": components["schemas"]["ErrorBodyResponse"];
        };
      };
    };
  };
  /**
   * Query the status of a specific bid.
   * @description Query the status of a specific bid.
   */
  bid_status: {
    parameters: {
      path: {
        /** @description Bid id to query for */
        bid_id: string;
      };
    };
    responses: {
      /** @description Latest status of the bid */
      200: {
        content: {
          "application/json": components["schemas"]["BidStatus"];
        };
      };
      400: components["responses"]["ErrorBodyResponse"];
      /** @description Bid was not found */
      404: {
        content: {
          "application/json": components["schemas"]["ErrorBodyResponse"];
        };
      };
    };
  };
  /**
   * Fetch all opportunities ready to be exectued.
   * @description Fetch all opportunities ready to be exectued.
   */
  get_opportunities: {
    parameters: {
      query?: {
        /** @example op_sepolia */
        chain_id?: string | null;
      };
    };
    responses: {
      /** @description Array of opportunities ready for bidding */
      200: {
        content: {
          "application/json": components["schemas"]["OpportunityParamsWithMetadata"][];
        };
      };
      400: components["responses"]["ErrorBodyResponse"];
      /** @description Chain id was not found */
      404: {
        content: {
          "application/json": components["schemas"]["ErrorBodyResponse"];
        };
      };
    };
  };
  /**
   * Submit an opportunity ready to be executed.
   * @description Submit an opportunity ready to be executed.
   *
   * The opportunity will be verified by the server. If the opportunity is valid, it will be stored in the database
   * and will be available for bidding.
   */
  post_opportunity: {
    requestBody: {
      content: {
        "application/json": components["schemas"]["OpportunityParams"];
      };
    };
    responses: {
      /** @description The created opportunity */
      200: {
        content: {
          "application/json": components["schemas"]["OpportunityParamsWithMetadata"];
        };
      };
      400: components["responses"]["ErrorBodyResponse"];
      /** @description Chain id was not found */
      404: {
        content: {
          "application/json": components["schemas"]["ErrorBodyResponse"];
        };
      };
    };
  };
  /**
   * Bid on opportunity
   * @description Bid on opportunity
   */
  opportunity_bid: {
    parameters: {
      path: {
        /** @description Opportunity id to bid on */
        opportunity_id: string;
      };
    };
    requestBody: {
      content: {
        "application/json": components["schemas"]["OpportunityBid"];
      };
    };
    responses: {
      /** @description Bid Result */
      200: {
        content: {
          "application/json": components["schemas"]["BidResult"];
        };
      };
      400: components["responses"]["ErrorBodyResponse"];
      /** @description Opportunity or chain id was not found */
      404: {
        content: {
          "application/json": components["schemas"]["ErrorBodyResponse"];
        };
      };
    };
  };
}
