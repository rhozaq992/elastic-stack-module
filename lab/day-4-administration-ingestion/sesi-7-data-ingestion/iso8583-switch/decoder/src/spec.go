// Spec ISO 8583:1987 ASCII (subset) untuk lab ini -- field number & definisi
// diambil dari spec referensi resmi library (github.com/moov-io/iso8583,
// examples/spec.go), BUKAN reverse-engineer dari switch bank manapun.
// Subset field dipilih supaya mewakili elemen umum transaksi kartu (PAN,
// processing code, amount, STAN, waktu, RRN, terminal, merchant, response
// code) tanpa memakai data institusi sungguhan. Dipakai SAMA PERSIS oleh
// generator (encode) dan decoder (decode) -- lihat README Sesi 7 topik baru
// "ISO 8583 Switch Simulator".
package main

import (
	"github.com/moov-io/iso8583"
	"github.com/moov-io/iso8583/encoding"
	"github.com/moov-io/iso8583/field"
	"github.com/moov-io/iso8583/padding"
	"github.com/moov-io/iso8583/prefix"
)

var switchSpec = &iso8583.MessageSpec{
	Name: "Lab ISO 8583 Switch Simulator (subset ISO 8583:1987 ASCII, dummy)",
	Fields: map[int]field.Field{
		0: field.NewString(&field.Spec{
			Length:      4,
			Description: "Message Type Indicator",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		1: field.NewBitmap(&field.Spec{
			// Length dalam BYTES (bukan hex char) menurut field.NewBitmap --
			// 8 byte = bitmap primer saja (field 1-64), cukup untuk subset
			// field lab ini (maksimal field 49), tanpa secondary bitmap.
			Length:      8,
			Description: "Bitmap",
			Enc:         encoding.BytesToASCIIHex,
			Pref:        prefix.Hex.Fixed,
		}),
		2: field.NewString(&field.Spec{
			Length:      19,
			Description: "Primary Account Number (PAN, dummy)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LL,
		}),
		3: field.NewNumeric(&field.Spec{
			Length:      6,
			Description: "Processing Code",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
			Pad:         padding.Left('0'),
		}),
		4: field.NewNumeric(&field.Spec{
			Length:      12,
			Description: "Transaction Amount (minor unit)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
			Pad:         padding.Left('0'),
		}),
		7: field.NewString(&field.Spec{
			Length:      10,
			Description: "Transmission Date & Time (MMDDhhmmss)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		11: field.NewString(&field.Spec{
			Length:      6,
			Description: "Systems Trace Audit Number (STAN)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		12: field.NewString(&field.Spec{
			Length:      6,
			Description: "Local Transaction Time (hhmmss)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		13: field.NewString(&field.Spec{
			Length:      4,
			Description: "Local Transaction Date (MMDD)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		15: field.NewString(&field.Spec{
			Length:      4,
			Description: "Settlement Date (MMDD, switch-specific — non-standard 4 chars, not YYMMDD)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		17: field.NewString(&field.Spec{
			Length:      4,
			Description: "Date, Capture (MMDD)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		18: field.NewString(&field.Spec{
			Length:      4,
			Description: "Merchant Type / MCC",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		28: field.NewString(&field.Spec{
			Length:      9,
			Description: "Amount, Transaction Fee (sign + amount)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		29: field.NewString(&field.Spec{
			Length:      9,
			Description: "Amount, Settlement Fee (sign + amount)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		32: field.NewString(&field.Spec{
			Length:      11,
			Description: "Acquiring Institution ID Code",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LL,
		}),
		37: field.NewString(&field.Spec{
			Length:      12,
			Description: "Retrieval Reference Number (RRN)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		39: field.NewString(&field.Spec{
			Length:      2,
			Description: "Response Code",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		41: field.NewString(&field.Spec{
			Length:      8,
			Description: "Card Acceptor Terminal Identification",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		42: field.NewString(&field.Spec{
			Length:      15,
			Description: "Card Acceptor Identification Code (Merchant ID)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		43: field.NewString(&field.Spec{
			Length:      40,
			Description: "Card Acceptor Name/Location",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		47: field.NewString(&field.Spec{
			Length:      999,
			Description: "Additional Data - National",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		48: field.NewString(&field.Spec{
			Length:      999,
			Description: "Additional Data - Private",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		49: field.NewString(&field.Spec{
			Length:      3,
			Description: "Transaction Currency Code",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.Fixed,
		}),
		54: field.NewString(&field.Spec{
			Length:      999,
			Description: "Additional Amounts",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		60: field.NewString(&field.Spec{
			Length:      999,
			Description: "Additional POS Info (Reserved Private/National)",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		61: field.NewString(&field.Spec{
			Length:      999,
			Description: "Reserved for Private Use",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		62: field.NewString(&field.Spec{
			Length:      999,
			Description: "Reserved for Private Use",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		63: field.NewString(&field.Spec{
			Length:      999,
			Description: "Reserved for Private Use",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		}),
		102: field.NewString(&field.Spec{
			Length:      28,
			Description: "Account Identification 1",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LL,
		}),
		103: field.NewString(&field.Spec{
			Length:      28,
			Description: "Account Identification 2",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LL,
		}),
	},
}

// Fields 104-127 are this switch's private-use range (self-describing
// LLLVAR, exact semantics unknown/undocumented) -- registered generically
// so decode doesn't need a rebuild every time a new one shows up in a
// capture file.
func init() {
	for id := 104; id <= 127; id++ {
		if _, ok := switchSpec.Fields[id]; ok {
			continue
		}
		switchSpec.Fields[id] = field.NewString(&field.Spec{
			Length:      999,
			Description: "Reserved for Private Use",
			Enc:         encoding.ASCII,
			Pref:        prefix.ASCII.LLL,
		})
	}
}
