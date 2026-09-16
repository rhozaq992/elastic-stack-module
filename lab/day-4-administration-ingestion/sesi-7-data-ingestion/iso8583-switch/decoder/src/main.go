// iso8583tool -- binary decoder/encoder ISO 8583 untuk lab Sesi 7 (ELK
// Stack Training). Dua subcommand:
//
//	iso8583tool encode   baca 1 baris JSON dari stdin {mti, f2, f3, ...},
//	                     tulis 1 baris hex mentah pesan ISO 8583 ke stdout.
//	                     Dipakai oleh log-generator (Python) supaya
//	                     encoding SELALU konsisten dengan spec Go ini.
//	iso8583tool decode   tail file log switch (@TAG@-wrapped), decode tiap
//	                     pesan ISO 8583 di dalamnya, tulis 1 baris JSON per
//	                     pesan ke stdout (dibaca Filebeat).
//
// Library: github.com/moov-io/iso8583 (github.com/moov-io/iso8583, 532
// stars per Sept 2026) -- lihat README Sesi 7 kenapa dipilih.
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/moov-io/iso8583"
)

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintln(os.Stderr, "usage: iso8583tool encode|decode [file...]")
		os.Exit(2)
	}
	switch os.Args[1] {
	case "encode":
		runEncode()
	case "decode":
		paths := os.Args[2:]
		if len(paths) == 0 {
			paths = []string{"-"}
		}
		runDecode(paths)
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand %q\n", os.Args[1])
		os.Exit(2)
	}
}

type txnFields struct {
	MTI string `json:"mti"`
	F2  string `json:"f2"`
	F3  string `json:"f3"`
	F4  string `json:"f4"`
	F7  string `json:"f7"`
	F11 string `json:"f11"`
	F12 string `json:"f12"`
	F13 string `json:"f13"`
	F37 string `json:"f37"`
	F39 string `json:"f39"`
	F41 string `json:"f41"`
	F42 string `json:"f42"`
	F49 string `json:"f49"`
}

// runEncode membaca satu baris JSON txnFields dari stdin, mengembalikan hex
// mentah pesan ISO 8583 (MTI + bitmap + field data) ke stdout.
func runEncode() {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var t txnFields
		if err := json.Unmarshal([]byte(line), &t); err != nil {
			fmt.Fprintf(os.Stderr, "encode: bad json: %v\n", err)
			continue
		}
		msg := iso8583.NewMessage(switchSpec)
		must(msg.Field(0, t.MTI))
		setIfNotEmpty(msg, 2, t.F2)
		setIfNotEmpty(msg, 3, t.F3)
		setIfNotEmpty(msg, 4, t.F4)
		setIfNotEmpty(msg, 7, t.F7)
		setIfNotEmpty(msg, 11, t.F11)
		setIfNotEmpty(msg, 12, t.F12)
		setIfNotEmpty(msg, 13, t.F13)
		setIfNotEmpty(msg, 37, t.F37)
		setIfNotEmpty(msg, 39, t.F39)
		setIfNotEmpty(msg, 41, t.F41)
		setIfNotEmpty(msg, 42, t.F42)
		setIfNotEmpty(msg, 49, t.F49)

		raw, err := msg.Pack()
		if err != nil {
			fmt.Fprintf(os.Stderr, "encode: pack error: %v\n", err)
			continue
		}
		fmt.Println(string(raw))
	}
}

func setIfNotEmpty(msg *iso8583.Message, id int, v string) {
	if v != "" {
		must(msg.Field(id, v))
	}
}

func must(err error) {
	if err != nil {
		fmt.Fprintf(os.Stderr, "field set error: %v\n", err)
	}
}

// runDecode men-tail SATU ATAU LEBIH file log switch secara konkuren
// (mis. switch-send.log dan switch-recv.log terpisah, mengikuti konvensi
// capture switch produksi yang memisah file per arah), masing-masing
// berformat:
//
//	@TAG@ <seq> <len> <dir> <HH:MM:SS.ffffff> <flag> <flag2> <internal-seq>
//	<pesan ISO 8583 mentah>
//
// Tiap file di-tail di goroutine sendiri (tail -f style, karena
// log-generator jalan sebagai proses panjang selama sesi 7), tapi SEMUA
// goroutine menulis lewat satu writer yang sama, dikunci mutex, supaya
// baris JSON dari 2 file yang bersamaan tidak saling interleave/corrupt
// di stdout (Filebeat mengasumsikan 1 objek JSON valid per baris).
func runDecode(paths []string) {
	out := bufio.NewWriter(os.Stdout)
	defer out.Flush()
	var writeMu sync.Mutex

	writeLine := func(b []byte) {
		writeMu.Lock()
		defer writeMu.Unlock()
		out.Write(b)
		out.WriteByte('\n')
		out.Flush()
	}

	if len(paths) == 1 && paths[0] == "-" {
		tailReader(os.Stdin, false, writeLine)
		return
	}

	var wg sync.WaitGroup
	for _, path := range paths {
		f, err := os.Open(path)
		if err != nil {
			fmt.Fprintf(os.Stderr, "decode: %v\n", err)
			os.Exit(1)
		}
		wg.Add(1)
		go func(f *os.File) {
			defer wg.Done()
			defer f.Close()
			tailReader(f, true, writeLine)
		}(f)
	}
	wg.Wait()
}

// tailReader membaca pasangan baris (@TAG@ + pesan) dari r, decode tiap
// pesan, lalu panggil writeLine dengan JSON hasilnya. Kalau tailing true,
// EOF tidak menghentikan pembacaan -- menunggu baris baru (mengikuti file
// yang terus ditulis proses lain), sama seperti `tail -f`.
func tailReader(r io.Reader, tailing bool, writeLine func([]byte)) {
	reader := bufio.NewReaderSize(r, 64*1024)
	var pendingTagLine string

	for {
		line, err := reader.ReadString('\n')
		line = strings.TrimRight(line, "\n")

		if line != "" {
			if strings.HasPrefix(line, "@TAG@") {
				pendingTagLine = line
			} else if pendingTagLine != "" {
				if b := decodeOneMessage(pendingTagLine, line); b != nil {
					writeLine(b)
				}
				pendingTagLine = ""
			}
		}

		if err != nil {
			if err == io.EOF {
				if !tailing {
					return
				}
				time.Sleep(500 * time.Millisecond)
				continue
			}
			fmt.Fprintf(os.Stderr, "decode: read error: %v\n", err)
			return
		}
	}
}

func decodeOneMessage(tagLine, msgLine string) []byte {
	msg := iso8583.NewMessage(switchSpec)
	if err := msg.Unpack([]byte(msgLine)); err != nil {
		fmt.Fprintf(os.Stderr, "decode: unpack error on line %q: %v\n", msgLine, err)
		return nil
	}

	fields := map[string]interface{}{}
	mti, _ := msg.GetMTI()
	fields["mti"] = mti

	names := map[int]string{
		2: "pan", 3: "processing_code", 4: "amount", 7: "transmission_datetime",
		11: "stan", 12: "local_time", 13: "local_date", 37: "rrn",
		39: "response_code", 41: "terminal_id", 42: "merchant_id", 49: "currency_code",
	}
	for id, name := range names {
		if v, err := msg.GetString(id); err == nil && v != "" {
			fields[name] = v
		}
	}

	// metadata dari envelope @TAG@ (seq/timestamp capture switch)
	parts := strings.Fields(tagLine)
	if len(parts) >= 8 {
		fields["capture_seq"] = parts[1]
		fields["capture_time"] = parts[4]
		fields["capture_direction"] = parts[5]
	}
	fields["@timestamp"] = time.Now().UTC().Format(time.RFC3339Nano)

	b, err := json.Marshal(fields)
	if err != nil {
		fmt.Fprintf(os.Stderr, "decode: json marshal error: %v\n", err)
		return nil
	}
	return b
}
