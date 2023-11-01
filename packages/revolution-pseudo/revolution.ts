interface CulturePiece {
  id: number;
  culture: CulturePieceMetadata; // Could be a URI pointing to the actual content (e.g., IPFS hash)
  uploader: string; // Ethereum address of the uploader
}

interface CulturePieceMetadata {
  name: string;
  description: string;
  image: string;
  animation_url?: string;
}

interface Voter {
  address: string;
  weight: number; // ERC20 token balance, for example
}

class CulturalIndex {
  private pieces: CulturePiece[];
  private votes: Map<number, Voter[]>; // Mapping from piece ID to an array of voters

  constructor() {
    this.pieces = [];
    this.votes = new Map();
  }

  // Event emitters
  private emitUploadEvent(piece: CulturePiece) {
    console.log(
      `Upload Event: Piece with ID ${piece.id} uploaded by ${piece.uploader}`
    );
  }

  private emitVoteEvent(pieceId: number, voter: Voter) {
    console.log(
      `Vote Event: Voter ${voter.address} voted for piece with ID ${pieceId}`
    );
  }

  // Upload a new piece of culture
  uploadPiece(culture: CulturePieceMetadata, uploader: string): number {
    const newId = this.pieces.length;
    const newPiece: CulturePiece = { id: newId, culture, uploader };
    this.pieces.push(newPiece);
    this.votes.set(newId, []);

    // Emit upload event
    this.emitUploadEvent(newPiece);

    return newId;
  }

  // Get a specific piece by its ID
  getPiece(pieceId: number): CulturePiece | null {
    if (pieceId >= this.pieces.length || pieceId < 0) {
      return null; // Invalid piece ID
    }
    return this.pieces[pieceId];
  }

  // Vote for a piece of culture
  vote(pieceId: number, voter: Voter): boolean {
    if (pieceId >= this.pieces.length) {
      return false; // Invalid piece ID
    }

    const voters = this.votes.get(pieceId) || [];

    // Check if the voter has already voted for this piece
    if (voters.some((v) => v.address === voter.address)) {
      return false; // Already voted
    }

    voters.push(voter);
    this.votes.set(pieceId, voters);

    // Emit vote event
    this.emitVoteEvent(pieceId, voter);

    return true;
  }

  // Get the total voting weight for a piece
  getVotingWeight(pieceId: number): number {
    const voters = this.votes.get(pieceId) || [];
    return voters.reduce((total, voter) => total + voter.weight, 0);
  }

  // Get votes for a specific piece by its ID
  getVotes(pieceId: number): Voter[] | null {
    if (pieceId >= this.pieces.length || pieceId < 0) {
      return null; // Invalid piece ID
    }
    return this.votes.get(pieceId) || [];
  }

  // Get both the piece and its votes by piece ID
  getPieceAndVotes(pieceId: number): {
    piece: CulturePiece | null;
    votes: Voter[] | null;
    votingWeight: number;
  } {
    const piece = this.getPiece(pieceId);
    const votes = this.getVotes(pieceId);
    const votingWeight = this.getVotingWeight(pieceId);
    return { piece, votes, votingWeight };
  }

  // List all pieces and their total voting weight
  listPieces(): { piece: CulturePiece; weight: number }[] {
    return this.pieces.map((p) => {
      return { piece: p, weight: this.getVotingWeight(p.id) };
    });
  }
}

// Example usage
const dao = new CulturalIndex();
const pieceId1 = dao.uploadPiece(
  { name: "Content1", description: "", image: "" },
  "0xAddress1"
);
const pieceId2 = dao.uploadPiece(
  { name: "Content2", description: "", image: "" },
  "0xAddress2"
);

dao.vote(pieceId1, { address: "0xVoter1", weight: 10 });
dao.vote(pieceId1, { address: "0xVoter2", weight: 20 });
dao.vote(pieceId2, { address: "0xVoter1", weight: 10 });

console.log("List of pieces and their voting weight:");
console.log(dao.listPieces());
